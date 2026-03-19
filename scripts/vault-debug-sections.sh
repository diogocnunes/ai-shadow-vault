#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vault-resolver.sh"
source "$SCRIPT_DIR/lib/managed-markdown.sh"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

FIX_MODE=0
FORCE_CONFLICTS=0
EXIT_CODE=0
OK_COUNT=0
WARN_COUNT=0
ERROR_COUNT=0
FIX_COUNT=0

usage() {
    cat <<'EOF'
Usage:
  vault-debug-sections [--fix] [--force-conflicts]

Options:
  --fix              Apply safe automatic fixes.
  --force-conflicts  With --fix, remove duplicate conflicting skill copies even when content differs.
  -h, --help  Show this help.
EOF
}

ok() {
    OK_COUNT=$((OK_COUNT + 1))
    echo -e "${GREEN}✔${NC} $1"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    echo -e "${YELLOW}⚠${NC} $1"
}

error_msg() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
    EXIT_CODE=1
    echo -e "${RED}✖${NC} $1"
}

fixed() {
    FIX_COUNT=$((FIX_COUNT + 1))
    echo -e "${BLUE}🛠${NC} $1"
}

rtk_version() {
    rtk --version 2>/dev/null || true
}

rtk_is_available() {
    local version
    version="$(rtk_version)"
    [[ "$version" == rtk\ * ]]
}

legacy_marker_present() {
    local file_path="$1"
    [ -f "$file_path" ] || return 1
    grep -qF "<!-- AI Shadow Vault: managed skills start -->" "$file_path" || \
        grep -qF "<!-- AI Shadow Vault: managed skills end -->" "$file_path"
}

normalize_legacy_markers() {
    local file_path="$1"
    [ -f "$file_path" ] || return 0

    if ! legacy_marker_present "$file_path"; then
        return 0
    fi

    sed -i '' \
        -e 's/<!-- AI Shadow Vault: managed skills start -->/<!-- AI_SHADOW_VAULT:START:skills -->/g' \
        -e 's/<!-- AI Shadow Vault: managed skills end -->/<!-- AI_SHADOW_VAULT:END:skills -->/g' \
        "$file_path"
    fixed "$(basename "$file_path"): normalized legacy skills markers"
}

parse_markers() {
    local file_path="$1"
    local report_path="$2"

    awk '
        function section_from_start(line, sec) {
            sec = line
            sub("^<!-- AI_SHADOW_VAULT:START:", "", sec)
            sub(" -->$", "", sec)
            return sec
        }

        function section_from_end(line, sec) {
            sec = line
            sub("^<!-- AI_SHADOW_VAULT:END:", "", sec)
            sub(" -->$", "", sec)
            return sec
        }

        function push(sec, line) {
            top++
            stack_sec[top] = sec
            stack_line[top] = line
        }

        function pop() {
            if (top > 0) {
                delete stack_sec[top]
                delete stack_line[top]
                top--
            }
        }

        {
            line = $0

            if (line ~ /^<!-- AI_SHADOW_VAULT:START:[a-z0-9-]+ -->$/) {
                sec = section_from_start(line)
                print "SECTION\t" sec
                print "START\t" sec "\t" NR
                push(sec, NR)
                next
            }

            if (line ~ /^<!-- AI_SHADOW_VAULT:END:[a-z0-9-]+ -->$/) {
                sec = section_from_end(line)
                print "SECTION\t" sec
                print "END\t" sec "\t" NR

                if (top == 0) {
                    print "ERR\tend-without-start\t" sec "\t" NR
                    next
                }

                if (stack_sec[top] == sec) {
                    print "PAIR\t" sec "\t" stack_line[top] "\t" NR
                    pop()
                    next
                }

                print "ERR\tmismatched-end\t" sec "\t" NR "\t" stack_sec[top]
                next
            }
        }

        END {
            while (top > 0) {
                print "ERR\tmissing-end\t" stack_sec[top] "\t" stack_line[top]
                top--
            }
        }
    ' "$file_path" > "$report_path"
}

cleanup_marker_structure() {
    local file_path="$1"
    local tmp_file

    tmp_file="$(mktemp)"
    awk '
        function section_from_start(line, sec) {
            sec = line
            sub("^<!-- AI_SHADOW_VAULT:START:", "", sec)
            sub(" -->$", "", sec)
            return sec
        }

        function section_from_end(line, sec) {
            sec = line
            sub("^<!-- AI_SHADOW_VAULT:END:", "", sec)
            sub(" -->$", "", sec)
            return sec
        }

        {
            lines[NR] = $0

            if ($0 ~ /^<!-- AI_SHADOW_VAULT:START:[a-z0-9-]+ -->$/) {
                top++
                stack_sec[top] = section_from_start($0)
                stack_line[top] = NR
                start_line[NR] = stack_sec[top]
                next
            }

            if ($0 ~ /^<!-- AI_SHADOW_VAULT:END:[a-z0-9-]+ -->$/) {
                sec = section_from_end($0)
                end_line[NR] = sec

                if (top > 0 && stack_sec[top] == sec) {
                    start = stack_line[top]
                    pair_count[sec]++
                    if (pair_count[sec] == 1) {
                        keep_start[start] = NR
                    } else {
                        remove_start[start] = NR
                    }
                    top--
                    next
                }

                orphan_end[NR] = 1
                next
            }
        }

        END {
            for (start in remove_start) {
                finish = remove_start[start]
                for (i = start; i <= finish; i++) {
                    remove_line[i] = 1
                }
            }

            for (i = 1; i <= top; i++) {
                orphan_start[stack_line[i]] = 1
            }

            for (i = 1; i <= NR; i++) {
                if (remove_line[i]) {
                    continue
                }

                if (orphan_start[i] || orphan_end[i]) {
                    continue
                }

                print lines[i]
            }
        }
    ' "$file_path" > "$tmp_file"

    mv "$tmp_file" "$file_path"
}

normalize_section_spacing() {
    local file_path="$1"
    local sections_path tmp_file section content

    sections_path="$(mktemp)"
    awk '
        /^<!-- AI_SHADOW_VAULT:START:[a-z0-9-]+ -->$/ {
            sec = $0
            sub("^<!-- AI_SHADOW_VAULT:START:", "", sec)
            sub(" -->$", "", sec)
            if (!seen[sec]++) {
                print sec
            }
        }
    ' "$file_path" > "$sections_path"

    if [ ! -s "$sections_path" ]; then
        rm -f "$sections_path"
        return 0
    fi

    tmp_file="$(mktemp)"
    cp "$file_path" "$tmp_file"

    while IFS= read -r section; do
        [ -n "$section" ] || continue
        content="$(vault_mm_extract_first_section_content "$tmp_file" "$section" 2>/dev/null || true)"
        if [ -z "$content" ]; then
            continue
        fi
        vault_mm_upsert_section "$tmp_file" "$section" "$content"
    done < "$sections_path"

    mv "$tmp_file" "$file_path"
    rm -f "$sections_path"
}

rtk_section_content() {
    cat <<'EOF_RTK'
RTK is installed in this environment. Use RTK wrappers instead of raw commands whenever an RTK equivalent exists.

Required rewrites:
- `git ...` -> `rtk git ...`
- `gh ...` -> `rtk gh ...`
- `cargo ...` -> `rtk cargo ...`
- `cat|head|tail <file>` -> `rtk read <file>`
- `rg|grep <pattern>` -> `rtk grep <pattern>`
- `ls` -> `rtk ls`
- `vitest|jest` -> `rtk vitest run`
- `tsc` -> `rtk tsc`
- `eslint|biome` -> `rtk lint`
- `prettier` -> `rtk prettier`
- `playwright` -> `rtk playwright`
- `prisma` -> `rtk prisma`
- `ruff ...` -> `rtk ruff ...`
- `pytest` -> `rtk pytest`
- `pip ...` -> `rtk pip ...`
- `go ...` -> `rtk go ...`
- `golangci-lint` -> `rtk golangci-lint`
- `docker ...` -> `rtk docker ...`
- `kubectl ...` -> `rtk kubectl ...`
- `curl` -> `rtk curl`
- `pnpm ...` -> `rtk pnpm ...`
EOF_RTK
}

docs_first_section_content() {
    cat <<'EOF_DOCS_FIRST'
Before implementing changes, inspect project-local documentation first:

1. Relevant root markdown files (`*.md` at project root).
2. `.ai/` context (`.ai/rules.md`, `.ai/plans/`, `.ai/docs/`, `.ai/context/`).
3. Any local documentation folders used by this repository.
4. Existing plans, conventions, and architecture notes already present in the repo.

If external library/API details are required and Context7 MCP is available in this environment, use Context7 before making assumptions.
Do not invent APIs, method signatures, configuration keys, or undocumented behavior.
EOF_DOCS_FIRST
}

resolve_target_path() {
    local vault_candidate="$1"
    local root_candidate="$2"

    if [ -f "$vault_candidate" ]; then
        printf '%s\n' "$vault_candidate"
        return
    fi

    if [ -f "$root_candidate" ]; then
        printf '%s\n' "$root_candidate"
        return
    fi

    printf '%s\n' "$vault_candidate"
}

scan_skill_roots() {
    local output_path="$1"
    local root path priority label
    local project_agents="$PROJECT_ROOT/.agents/skills"
    local project_codex="$PROJECT_ROOT/.codex/skills"
    local project_gemini="$PROJECT_ROOT/.gemini/skills"

    : > "$output_path"

    for root in \
        "$project_agents:1:project/.agents" \
        "$project_codex:2:project/.codex" \
        "$project_gemini:3:project/.gemini" \
        "$HOME/.codex/skills:4:home/.codex" \
        "$HOME/.gemini/skills:5:home/.gemini"; do
        IFS=':' read -r path priority label <<< "$root"
        [ -d "$path" ] || continue

        find "$path" -mindepth 2 -maxdepth 2 -name SKILL.md | while IFS= read -r skill_file; do
            skill_name="$(basename "$(dirname "$skill_file")")"
            printf '%s\t%s\t%s\t%s\n' "$skill_name" "$priority" "$label" "$skill_file" >> "$output_path"
        done
    done
}

for arg in "$@"; do
    case "$arg" in
        --fix)
            FIX_MODE=1
            ;;
        --force-conflicts)
            FORCE_CONFLICTS=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage
            exit 1
            ;;
    esac
done

if [ "$FORCE_CONFLICTS" -eq 1 ] && [ "$FIX_MODE" -ne 1 ]; then
    echo "--force-conflicts requires --fix" >&2
    usage
    exit 1
fi

PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
PROJECT_VAULT="$(vault_resolve_existing_project_vault "$PROJECT_ROOT")"

MANAGED_TARGETS=(
    "CLAUDE.md:$PROJECT_VAULT/CLAUDE.md:$PROJECT_ROOT/CLAUDE.md"
    "GEMINI.md:$PROJECT_VAULT/GEMINI.md:$PROJECT_ROOT/GEMINI.md"
    "AGENTS.md:$PROJECT_VAULT/AGENTS.md:$PROJECT_ROOT/AGENTS.md"
    ".cursorrules:$PROJECT_VAULT/.cursorrules:$PROJECT_ROOT/.cursorrules"
    ".windsurfrules:$PROJECT_VAULT/.windsurfrules:$PROJECT_ROOT/.windsurfrules"
    "copilot-instructions.md:$PROJECT_VAULT/copilot-instructions.md:$PROJECT_ROOT/.github/copilot-instructions.md"
)

echo -e "${BLUE}🔍 AI Shadow Vault Debug${NC}"
echo "Project root: $PROJECT_ROOT"
echo "Vault path:   $PROJECT_VAULT"
echo ""

rtk_version_value="$(rtk_version)"
rtk_available=0
if [[ "$rtk_version_value" == rtk\ * ]]; then
    rtk_available=1
fi

managed_tmp="$(mktemp)"
validation_tmp="$(mktemp)"
drift_tmp="$(mktemp)"

: > "$managed_tmp"
: > "$validation_tmp"
: > "$drift_tmp"

echo "=== Managed Sections ==="

for target in "${MANAGED_TARGETS[@]}"; do
    IFS=':' read -r label vault_candidate root_candidate <<< "$target"
    file_path="$(resolve_target_path "$vault_candidate" "$root_candidate")"

    if [ ! -f "$file_path" ]; then
        warn "$label -> missing file at $file_path"
        printf '%s\t%s\tmissing\n' "$label" "$file_path" >> "$drift_tmp"
        continue
    fi

    report_file="$(mktemp)"
    parse_markers "$file_path" "$report_file"

    section_list="$(awk -F'\t' '$1=="SECTION"{print $2}' "$report_file" | sort -u | tr '\n' ',' | sed 's/,$//')"
    has_markers=0
    [ -n "$section_list" ] && has_markers=1

    if [ "$has_markers" -eq 1 ]; then
        ok "$label -> sections: $section_list"
    else
        warn "$label -> no canonical managed sections"
    fi

    printf '%s\t%s\t%s\t%s\n' "$label" "$file_path" "$has_markers" "$section_list" >> "$managed_tmp"

    dup_starts="$(awk -F'\t' '$1=="START"{count[$2]++} END {for (s in count) if (count[s] > 1) print s "\t" count[s]}' "$report_file")"
    if [ -n "$dup_starts" ]; then
        while IFS=$'\t' read -r section count; do
            [ -n "$section" ] || continue
            error_msg "$label -> duplicate START:$section ($count)"
            printf '%s\t%s\tduplicate-start\t%s\t%s\n' "$label" "$file_path" "$section" "$count" >> "$validation_tmp"
        done <<< "$dup_starts"
    fi

    marker_errors="$(awk -F'\t' '$1=="ERR"{print $2 "\t" $3 "\t" $4 "\t" $5}' "$report_file")"
    if [ -n "$marker_errors" ]; then
        while IFS=$'\t' read -r err_type section line extra; do
            [ -n "$err_type" ] || continue
            case "$err_type" in
                missing-end)
                    error_msg "$label -> missing END:$section (start line $line)"
                    ;;
                end-without-start)
                    error_msg "$label -> END without START:$section (line $line)"
                    ;;
                mismatched-end)
                    error_msg "$label -> mismatched END:$section (line $line, expected END:$extra)"
                    ;;
                *)
                    error_msg "$label -> marker error:$err_type section:$section line:$line"
                    ;;
            esac
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$file_path" "$err_type" "$section" "$line" "$extra" >> "$validation_tmp"
        done <<< "$marker_errors"
    fi

    if [ "$FIX_MODE" -eq 1 ]; then
        before_hash="$(shasum "$file_path" | awk '{print $1}')"
        can_modify=0
        if vault_mm_has_any_section "$file_path" || legacy_marker_present "$file_path"; then
            can_modify=1
        fi

        if [ "$can_modify" -eq 1 ]; then
            normalize_legacy_markers "$file_path"
            cleanup_marker_structure "$file_path"
            normalize_section_spacing "$file_path"
        fi

        if [ "$can_modify" -eq 1 ] && vault_mm_has_any_section "$file_path"; then
            docs_content="$(docs_first_section_content)"
            if vault_mm_has_section "$file_path" "docs-first"; then
                vault_mm_upsert_section "$file_path" "docs-first" "$docs_content"
            else
                vault_mm_append_section_once "$file_path" "docs-first" "$docs_content"
            fi

            if [ "$rtk_available" -eq 1 ]; then
                if vault_mm_has_section "$file_path" "rtk"; then
                    content="$(rtk_section_content)"
                    vault_mm_upsert_section "$file_path" "rtk" "$content"
                else
                    content="$(rtk_section_content)"
                    vault_mm_append_section_once "$file_path" "rtk" "$content"
                fi
            else
                if vault_mm_has_section "$file_path" "rtk"; then
                    vault_mm_remove_section "$file_path" "rtk"
                fi
            fi
        fi

        after_hash="$(shasum "$file_path" | awk '{print $1}')"
        if [ "$before_hash" != "$after_hash" ]; then
            fixed "$label: applied safe marker fixes"
        fi
    fi

    rm -f "$report_file"
done

echo ""
echo "=== RTK ==="
if [ "$rtk_available" -eq 1 ]; then
    ok "RTK detected: $rtk_version_value"
else
    warn "RTK not detected"
fi

while IFS=$'\t' read -r label file_path has_markers sections; do
    [ "$has_markers" = "missing" ] && continue
    [ -f "$file_path" ] || continue

    if [ "$rtk_available" -eq 1 ]; then
        if [ "$has_markers" -eq 1 ] && ! vault_mm_has_section "$file_path" "rtk"; then
            warn "$label -> missing rtk section while RTK is installed"
            printf '%s\t%s\tmissing-rtk\n' "$label" "$file_path" >> "$drift_tmp"
        fi
    else
        if vault_mm_has_section "$file_path" "rtk"; then
            error_msg "$label -> stale rtk section while RTK is unavailable"
            printf '%s\t%s\tstale-rtk\n' "$label" "$file_path" >> "$drift_tmp"
        fi
    fi
done < "$managed_tmp"

echo ""
echo "=== Skills ==="

skills_tmp="$(mktemp)"
scan_skill_roots "$skills_tmp"

if [ ! -s "$skills_tmp" ]; then
    ok "No skill roots found for conflict analysis (.agents/.codex/.gemini)."
else
    conflicts_tmp="$(mktemp)"
    cut -f1 "$skills_tmp" | sort | uniq -d > "$conflicts_tmp"

    if [ ! -s "$conflicts_tmp" ]; then
        ok "No skill conflicts detected across roots."
    else
        while IFS= read -r skill_name; do
            [ -n "$skill_name" ] || continue
            warn "Skill conflict detected: $skill_name"

            entries_tmp="$(mktemp)"
            awk -F'\t' -v skill="$skill_name" '$1==skill{print $0}' "$skills_tmp" | sort -t$'\t' -k2,2n > "$entries_tmp"

            used_path="$(head -n1 "$entries_tmp" | awk -F'\t' '{print $4}')"
            used_label="$(head -n1 "$entries_tmp" | awk -F'\t' '{print $3}')"
            echo "  Precedence used for debug: project/.agents > project/.codex > project/.gemini > home/.codex > home/.gemini"

            while IFS=$'\t' read -r _skill _priority root_label skill_path; do
                [ -n "$skill_path" ] || continue
                if [ "$skill_path" = "$used_path" ]; then
                    echo "  - $root_label/$skill_name (used)"
                else
                    echo "  - $root_label/$skill_name (ignored)"
                fi
            done < "$entries_tmp"

            if [ "$FIX_MODE" -eq 1 ]; then
                can_remove=1
                while IFS=$'\t' read -r _skill _priority _root skill_path; do
                    [ "$skill_path" = "$used_path" ] && continue
                    if ! cmp -s "$used_path" "$skill_path"; then
                        can_remove=0
                        break
                    fi
                done < "$entries_tmp"

                if [ "$can_remove" -eq 1 ]; then
                    while IFS=$'\t' read -r _skill _priority _root skill_path; do
                        [ "$skill_path" = "$used_path" ] && continue
                        skill_dir="$(dirname "$skill_path")"
                        rm -f "$skill_path"
                        rmdir "$skill_dir" 2>/dev/null || true
                        fixed "removed duplicate identical skill copy: $skill_path"
                    done < "$entries_tmp"
                elif [ "$FORCE_CONFLICTS" -eq 1 ]; then
                    while IFS=$'\t' read -r _skill _priority _root skill_path; do
                        [ "$skill_path" = "$used_path" ] && continue
                        skill_dir="$(dirname "$skill_path")"
                        rm -f "$skill_path"
                        rmdir "$skill_dir" 2>/dev/null || true
                        fixed "force-removed conflicting skill copy (kept $used_label): $skill_path"
                    done < "$entries_tmp"
                else
                    warn "Cannot auto-fix conflict for $skill_name: content differs"
                fi
            fi

            rm -f "$entries_tmp"
        done < "$conflicts_tmp"
    fi

    rm -f "$conflicts_tmp"
fi

echo ""
echo "=== Marker Validation ==="
if [ -s "$validation_tmp" ]; then
    while IFS=$'\t' read -r label _file err_type section line extra; do
        case "$err_type" in
            duplicate-start)
                echo -e "${RED}✖${NC} $label -> duplicate START:$section"
                ;;
            missing-end)
                echo -e "${RED}✖${NC} $label -> missing END:$section"
                ;;
            end-without-start)
                echo -e "${RED}✖${NC} $label -> END without START:$section"
                ;;
            mismatched-end)
                echo -e "${RED}✖${NC} $label -> mismatched END:$section (expected END:$extra)"
                ;;
            *)
                echo -e "${RED}✖${NC} $label -> marker issue:$err_type section:$section line:$line"
                ;;
        esac
    done < "$validation_tmp"
else
    ok "No marker integrity errors detected."
fi

echo ""
echo "=== Drift Detection ==="
docs_missing=0
managed_with_sections=0
while IFS=$'\t' read -r label file_path has_markers _sections; do
    [ "$has_markers" = "missing" ] && continue
    [ "$has_markers" -eq 1 ] || continue
    managed_with_sections=$((managed_with_sections + 1))
    if [ -f "$file_path" ] && ! vault_mm_has_section "$file_path" "docs-first"; then
        warn "$label -> missing docs-first section"
        docs_missing=$((docs_missing + 1))
    fi
done < "$managed_tmp"

if [ "$managed_with_sections" -eq 0 ]; then
    warn "No managed target currently contains canonical markers."
fi

if [ "$docs_missing" -eq 0 ] && [ ! -s "$drift_tmp" ]; then
    ok "No drift detected."
fi

echo ""
echo "=== Suggestions ==="
if [ "$FIX_MODE" -eq 0 ]; then
    echo "- Run \`vault-debug-sections --fix\` to apply safe automatic fixes."
fi
echo "- Re-run \`vault-init --force-config\` if managed targets require full regeneration."
echo "- Run \`vault-skills standardize\` when skills marker formats diverge."

echo ""
echo "Summary: OK=$OK_COUNT WARN=$WARN_COUNT ERROR=$ERROR_COUNT FIXED=$FIX_COUNT"

rm -f "$managed_tmp" "$validation_tmp" "$drift_tmp" "$skills_tmp"
exit "$EXIT_CODE"
