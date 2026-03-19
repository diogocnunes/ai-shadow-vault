#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vault-resolver.sh"
source "$SCRIPT_DIR/lib/skills-resolver.sh"
source "$SCRIPT_DIR/lib/extensions-resolver.sh"
source "$SCRIPT_DIR/lib/managed-markdown.sh"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SKILLS_MANAGED_START="<!-- AI_SHADOW_VAULT:START:skills -->"
SKILLS_MANAGED_END="<!-- AI_SHADOW_VAULT:END:skills -->"
SKILLS_LEGACY_MANAGED_START="<!-- AI Shadow Vault: managed skills start -->"
SKILLS_LEGACY_MANAGED_END="<!-- AI Shadow Vault: managed skills end -->"

PROJECT_ROOT="$(skills_project_root "$PWD")"
vault_extension_notice_if_disabled "$PROJECT_ROOT" "skills" "vault-skills" || true

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

rtk_is_available() {
    local version
    version="$(rtk --version 2>/dev/null || true)"
    [[ "$version" == rtk\ * ]]
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

normalize_target_name() {
    local target
    target="$(skills_normalize_name "${1:-}")"

    case "$target" in
        gemini|gemini-cli|gemini-global)
            echo "gemini"
            ;;
        codex|openai-codex)
            echo "codex"
            ;;
        claude|claude-code)
            echo "claude"
            ;;
        cursor)
            echo "cursor"
            ;;
        windsurf)
            echo "windsurf"
            ;;
        copilot|github-copilot)
            echo "copilot"
            ;;
        junie|cody|cody-junie)
            echo "junie"
            ;;
        opencode)
            echo "opencode"
            ;;
        *)
            return 1
            ;;
    esac
}

supported_targets() {
    printf '%s\n' gemini codex claude cursor windsurf copilot junie opencode
}

supported_target_presets() {
    printf '%s\n' all native editors context
}

supported_skill_presets() {
    printf '%s\n' \
        planning \
        reviewing \
        reviewing-laravel \
        reviewing-laravel-nova \
        reviewing-filament \
        laravel-nova \
        filament \
        tall-stack \
        qa \
        security \
        frontend \
        fullstack
}

expand_skill_preset() {
    case "${1:-}" in
        planning)
            printf '%s\n' \
                user-stories
            ;;
        reviewing)
            printf '%s\n' \
                code-review \
                dx-maintainer \
                qa-automation
            ;;
        reviewing-laravel)
            printf '%s\n' \
                code-review \
                backend-expert \
                laravel-code-quality \
                qa-automation \
                security-performance
            ;;
        reviewing-laravel-nova)
            printf '%s\n' \
                code-review \
                architect-lead \
                backend-expert \
                laravel-code-quality \
                legacy-migration-specialist \
                qa-automation \
                security-performance
            ;;
        reviewing-filament)
            printf '%s\n' \
                code-review \
                architect-filament-lead \
                backend-expert \
                filament-v5 \
                frontend-expert \
                laravel-code-quality \
                qa-automation \
                security-performance
            ;;
        laravel-nova)
            printf '%s\n' \
                architect-lead \
                backend-expert \
                dx-maintainer \
                frontend-expert \
                laravel-code-quality \
                legacy-migration-specialist \
                qa-automation \
                security-performance
            ;;
        filament)
            printf '%s\n' \
                architect-filament-lead \
                backend-expert \
                dx-maintainer \
                filament-v5 \
                frontend-expert \
                laravel-code-quality \
                qa-automation \
                security-performance
            ;;
        tall-stack)
            printf '%s\n' \
                backend-expert \
                dx-maintainer \
                frontend-expert \
                laravel-code-quality \
                qa-automation \
                security-performance \
                tall-stack
            ;;
        qa)
            printf '%s\n' \
                dx-maintainer \
                qa-automation
            ;;
        security)
            printf '%s\n' \
                backend-expert \
                laravel-code-quality \
                security-performance
            ;;
        frontend)
            printf '%s\n' \
                dx-maintainer \
                frontend-expert
            ;;
        fullstack)
            printf '%s\n' \
                architect-lead \
                backend-expert \
                dx-maintainer \
                frontend-expert \
                laravel-code-quality \
                legacy-migration-specialist \
                qa-automation \
                security-performance \
                syncfusion-document-editor \
                tall-stack
            ;;
        *)
            return 1
            ;;
    esac
}

dedupe_lines() {
    awk '!seen[$0]++'
}

resolve_requested_targets() {
    local requested normalized_target
    local -a resolved=()

    if [[ "$#" -eq 0 ]]; then
        while IFS= read -r requested; do
            [[ -n "$requested" ]] && resolved+=("$requested")
        done < <(skills_load_targets "$PROJECT_ROOT")
    else
        for requested in "$@"; do
            case "$requested" in
                --all|all)
                    while IFS= read -r normalized_target; do
                        resolved+=("$normalized_target")
                    done < <(supported_targets)
                    ;;
                native)
                    resolved+=(gemini codex)
                    ;;
                editors)
                    resolved+=(cursor windsurf copilot)
                    ;;
                context)
                    resolved+=(claude junie opencode)
                    ;;
                *)
                    normalized_target="$(normalize_target_name "$requested")"
                    resolved+=("$normalized_target")
                    ;;
            esac
        done
    fi

    if [[ "${#resolved[@]}" -eq 0 ]]; then
        return 0
    fi

    printf '%s\n' "${resolved[@]+"${resolved[@]}"}" | dedupe_lines
}

resolve_requested_skills() {
    local requested resolved_line normalized_name
    local -a resolved=()

    for requested in "$@"; do
        resolved_line="$(skills_resolve_one "$requested")"
        IFS=$'\t' read -r normalized_name _ _ <<< "$resolved_line"
        resolved+=("$normalized_name")
    done

    if [[ "${#resolved[@]}" -eq 0 ]]; then
        return 0
    fi

    printf '%s\n' "${resolved[@]+"${resolved[@]}"}" | dedupe_lines
}

project_slug() {
    vault_resolve_project_slug "$PROJECT_ROOT"
}

render_base_template() {
    local target="$1"
    local slug
    slug="$(project_slug)"

    case "$target" in
        claude)
            if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
                sanitize_existing_file "claude" "$PROJECT_ROOT/CLAUDE.md"
            else
                sed "s/{{PROJECT_NAME}}/$slug/g" "$SCRIPT_DIR/../templates/CLAUDE.md"
            fi
            ;;
        gemini)
            if [[ -f "$PROJECT_ROOT/GEMINI.md" ]]; then
                sanitize_existing_file "gemini" "$PROJECT_ROOT/GEMINI.md"
            else
                sed "s/{{PROJECT_NAME}}/$slug/g" "$SCRIPT_DIR/../templates/GEMINI.md"
            fi
            ;;
        cursor)
            if [[ -f "$PROJECT_ROOT/.cursorrules" ]]; then
                sanitize_existing_file "cursor" "$PROJECT_ROOT/.cursorrules"
            else
                cat "$SCRIPT_DIR/../templates/.cursorrules"
            fi
            ;;
        windsurf)
            if [[ -f "$PROJECT_ROOT/.windsurfrules" ]]; then
                sanitize_existing_file "windsurf" "$PROJECT_ROOT/.windsurfrules"
            else
                cat "$SCRIPT_DIR/../templates/.windsurfrules"
            fi
            ;;
        copilot)
            if [[ -f "$PROJECT_ROOT/.github/copilot-instructions.md" ]]; then
                sanitize_existing_file "copilot" "$PROJECT_ROOT/.github/copilot-instructions.md"
            else
                sed "s/{Project Name}/$slug/g" "$SCRIPT_DIR/../templates/copilot-instructions.md"
            fi
            ;;
        opencode)
            sed "s/{Project Name}/$slug/g" "$SCRIPT_DIR/../templates/opencode.sample.json"
            ;;
        *)
            return 1
            ;;
    esac
}

upsert_standard_sections_if_supported() {
    local target="$1"
    local destination="$2"
    local docs_content rtk_content

    case "$target" in
        claude|gemini|cursor|windsurf|copilot)
            ;;
        *)
            return 0
            ;;
    esac

    [[ -f "$destination" ]] || return 0

    docs_content="$(docs_first_section_content)"
    if vault_mm_has_section "$destination" "docs-first"; then
        vault_mm_upsert_section "$destination" "docs-first" "$docs_content"
    else
        vault_mm_append_section_once "$destination" "docs-first" "$docs_content"
    fi

    if rtk_is_available; then
        rtk_content="$(rtk_section_content)"
        if vault_mm_has_section "$destination" "rtk"; then
            vault_mm_upsert_section "$destination" "rtk" "$rtk_content"
        else
            vault_mm_append_section_once "$destination" "rtk" "$rtk_content"
        fi
    else
        vault_mm_remove_section "$destination" "rtk"
    fi
}

sanitize_existing_file() {
    local target="$1"
    local file_path="$2"
    local stripped_content
    stripped_content="$(
        awk -v managed_start="$SKILLS_MANAGED_START" -v managed_end="$SKILLS_MANAGED_END" -v legacy_start="$SKILLS_LEGACY_MANAGED_START" -v legacy_end="$SKILLS_LEGACY_MANAGED_END" '
            $0 == managed_start || $0 == legacy_start { in_managed = 1; next }
            $0 == managed_end || $0 == legacy_end { in_managed = 0; next }
            !in_managed { print }
        ' "$file_path"
    )"

    if [[ "$target" == "claude" ]]; then
        printf '%s\n' "$stripped_content" | awk '
            pending_dash && /^name:[[:space:]]*/ { exit }
            pending_dash {
                print "---"
                pending_dash = 0
            }
            /^---$/ {
                pending_dash = 1
                next
            }
            { print }
        '
        return
    fi

    printf '%s\n' "$stripped_content" | awk '
        /^## Skill:/ { exit }
        { print }
    '
}

managed_skills_block() {
    local bundle_path="$1"

    cat <<EOF
$SKILLS_MANAGED_START
The active skills bundle lives at:

\`.ai/skills/ACTIVE_SKILLS.md\`

Consult that file when it exists before applying specialized guidance.

EOF

    if [[ -f "$bundle_path" ]]; then
        printf 'Bundle status: generated and available.\n'
    else
        printf 'Bundle status: no active skills selected yet.\n'
    fi

    echo "$SKILLS_MANAGED_END"
}

write_target_file() {
    local target="$1"
    local destination="$2"
    local bundle_path="$3"
    local base_content

    mkdir -p "$(dirname "$destination")"
    base_content="$(render_base_template "$target")"

    {
        printf '%s\n' "$base_content"
        echo
        managed_skills_block "$bundle_path"
    } > "$destination"

    upsert_standard_sections_if_supported "$target" "$destination"
}

install_skill_gemini() {
    local skill_name="$1"
    local skill_file="$2"
    local target_dir="$HOME/.gemini/skills/$skill_name"
    mkdir -p "$target_dir"
    cp "$skill_file" "$target_dir/SKILL.md"
}

install_skill_codex() {
    local skill_name="$1"
    local skill_file="$2"
    local target_dir="$HOME/.codex/skills/$skill_name"
    mkdir -p "$target_dir"
    cp "$skill_file" "$target_dir/SKILL.md"
}

apply_context_target() {
    local target="$1"
    local bundle_path="$2"

    case "$target" in
        claude)
            write_target_file "claude" "$PROJECT_ROOT/CLAUDE.md" "$bundle_path"
            ;;
        cursor)
            write_target_file "cursor" "$PROJECT_ROOT/.cursorrules" "$bundle_path"
            ;;
        windsurf)
            write_target_file "windsurf" "$PROJECT_ROOT/.windsurfrules" "$bundle_path"
            ;;
        copilot)
            write_target_file "copilot" "$PROJECT_ROOT/.github/copilot-instructions.md" "$bundle_path"
            ;;
        opencode)
            mkdir -p "$PROJECT_ROOT/.opencode"
            cp "$bundle_path" "$PROJECT_ROOT/.opencode/ACTIVE_SKILLS.md"
            if [[ ! -f "$PROJECT_ROOT/.opencode.json" ]]; then
                render_base_template "opencode" > "$PROJECT_ROOT/.opencode.json"
            fi
            ;;
        junie)
            mkdir -p "$PROJECT_ROOT/.junie"
            cp "$bundle_path" "$PROJECT_ROOT/.junie/ACTIVE_SKILLS.md"
            ;;
        *)
            return 1
            ;;
    esac
}

write_standardized_markers() {
    local bundle_path="$1"
    write_target_file "claude" "$PROJECT_ROOT/CLAUDE.md" "$bundle_path"
    write_target_file "gemini" "$PROJECT_ROOT/GEMINI.md" "$bundle_path"
    write_target_file "cursor" "$PROJECT_ROOT/.cursorrules" "$bundle_path"
    write_target_file "windsurf" "$PROJECT_ROOT/.windsurfrules" "$bundle_path"
    write_target_file "copilot" "$PROJECT_ROOT/.github/copilot-instructions.md" "$bundle_path"
    apply_context_target "opencode" "$bundle_path"
    apply_context_target "junie" "$bundle_path"
}

classify_file() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        echo "missing"
        return
    fi

    if grep -qF "$SKILLS_MANAGED_START" "$file_path" || grep -qF "$SKILLS_LEGACY_MANAGED_START" "$file_path"; then
        echo "canonical"
        return
    fi

    if grep -q "^## Skill:" "$file_path" || grep -q "^name:[[:space:]]" "$file_path"; then
        echo "legacy-appended"
        return
    fi

    echo "unknown-manual"
}

backup_file_if_present() {
    local file_path="$1"
    local backup_root="$2"

    [[ -f "$file_path" ]] || return 0

    mkdir -p "$backup_root"
    cp "$file_path" "$backup_root/$(basename "$file_path")"
}

command_list() {
    echo -e "${BLUE}Available installable skills:${NC}"
    skills_discover | while IFS=$'\t' read -r skill_name _ skill_desc; do
        printf '  %-32s %s\n' "$skill_name" "$skill_desc"
    done
    echo
    echo "Target presets: all native editors context"
    echo "Skill presets: planning reviewing reviewing-laravel reviewing-laravel-nova reviewing-filament laravel-nova filament tall-stack qa security frontend fullstack"
}

command_presets() {
    local preset skill_name

    echo -e "${BLUE}Available skill presets:${NC}"
    for preset in $(supported_skill_presets); do
        echo
        echo "  $preset"
        while IFS= read -r skill_name; do
            echo "    - $skill_name"
        done < <(expand_skill_preset "$preset")
    done
}

command_status() {
    local -a active_skills=()
    local -a targets=()
    local item

    while IFS= read -r item; do
        [[ -n "$item" ]] && active_skills+=("$item")
    done < <(skills_load_active_names "$PROJECT_ROOT")

    while IFS= read -r item; do
        [[ -n "$item" ]] && targets+=("$item")
    done < <(skills_load_targets "$PROJECT_ROOT")

    echo -e "${BLUE}AI Shadow Vault Skills Status${NC}"
    echo "Project Root: $PROJECT_ROOT"
    echo "Bundle: $(skills_active_bundle_file "$PROJECT_ROOT")"
    echo
    echo "Active Skills:"
    if [[ "${#active_skills[@]}" -eq 0 ]]; then
        echo "  - none"
    else
        for item in "${active_skills[@]}"; do
            echo "  - $item"
        done
    fi
    echo
    echo "Targets:"
    if [[ "${#targets[@]}" -eq 0 ]]; then
        echo "  - none"
    else
        for item in "${targets[@]}"; do
            echo "  - $item"
        done
    fi
}

sync_to_targets() {
    local -a skill_names=()
    local -a targets=()
    local bundle_path resolved_line skill_name skill_file skill_desc target

    while IFS= read -r skill_name; do
        [[ -n "$skill_name" ]] && skill_names+=("$skill_name")
    done < <(skills_load_active_names "$PROJECT_ROOT")

    while IFS= read -r target; do
        [[ -n "$target" ]] && targets+=("$target")
    done < <(skills_load_targets "$PROJECT_ROOT")

    if [[ "${#targets[@]}" -eq 0 ]]; then
        echo -e "${YELLOW}No stored targets found. Nothing to sync.${NC}"
        return 0
    fi

    if [[ "${#skill_names[@]}" -gt 0 ]]; then
        "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" "${skill_names[@]+"${skill_names[@]}"}" >/dev/null
    else
        "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" >/dev/null
    fi
    bundle_path="$(skills_active_bundle_file "$PROJECT_ROOT")"

    for skill_name in "${skill_names[@]}"; do
        resolved_line="$(skills_resolve_one "$skill_name")"
        IFS=$'\t' read -r skill_name skill_file skill_desc <<< "$resolved_line"

        for target in "${targets[@]}"; do
            case "$target" in
                gemini)
                    install_skill_gemini "$skill_name" "$skill_file"
                    ;;
                codex)
                    install_skill_codex "$skill_name" "$skill_file"
                    ;;
            esac
        done
    done

    for target in "${targets[@]}"; do
        case "$target" in
            claude|cursor|windsurf|copilot|junie|opencode)
                apply_context_target "$target" "$bundle_path"
                ;;
            gemini)
                write_target_file "gemini" "$PROJECT_ROOT/GEMINI.md" "$bundle_path"
                ;;
            codex)
                mkdir -p "$PROJECT_ROOT/.codex"
                cp "$bundle_path" "$PROJECT_ROOT/.codex/ACTIVE_SKILLS.md"
                ;;
        esac
    done
}

command_activate() {
    local -a skills=()
    local -a targets=()
    local -a state_args=()
    local -a requested=()
    local skill_name arg

    while [[ "$#" -gt 0 ]]; do
        arg="$1"
        shift

        case "$arg" in
            --preset)
                [[ "$#" -gt 0 ]] || { echo -e "${RED}Missing preset name after --preset.${NC}"; exit 1; }
                while IFS= read -r skill_name; do
                    [[ -n "$skill_name" ]] && requested+=("$skill_name")
                done < <(expand_skill_preset "$1")
                shift
                ;;
            preset:*)
                while IFS= read -r skill_name; do
                    [[ -n "$skill_name" ]] && requested+=("$skill_name")
                done < <(expand_skill_preset "${arg#preset:}")
                ;;
            *)
                requested+=("$arg")
                ;;
        esac
    done

    while IFS= read -r skill_name; do
        [[ -n "$skill_name" ]] && skills+=("$skill_name")
    done < <(resolve_requested_skills "${requested[@]}")

    while IFS= read -r skill_name; do
        [[ -n "$skill_name" ]] && targets+=("$skill_name")
    done < <(skills_load_targets "$PROJECT_ROOT")

    skills_write_list_file "$(skills_active_file "$PROJECT_ROOT")" "${skills[@]+"${skills[@]}"}"
    state_args=()
    if [[ "${#skills[@]}" -gt 0 ]]; then
        state_args+=("${skills[@]}")
    fi
    state_args+=("--targets")
    if [[ "${#targets[@]}" -gt 0 ]]; then
        state_args+=("${targets[@]}")
    fi
    skills_write_state_json "$PROJECT_ROOT" "${state_args[@]}"
    if [[ "${#skills[@]}" -gt 0 ]]; then
        "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" "${skills[@]}" >/dev/null
    else
        "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" >/dev/null
    fi

    echo -e "${GREEN}Active skills updated.${NC}"
    echo "Skills: ${skills[*]}"
    echo "Bundle: $(skills_active_bundle_file "$PROJECT_ROOT")"
}

command_sync() {
    local -a targets=()
    local arg target

    while IFS= read -r target; do
        [[ -n "$target" ]] && targets+=("$target")
    done < <(resolve_requested_targets "$@")

    if [[ "${#targets[@]}" -gt 0 ]]; then
        skills_write_list_file "$(skills_targets_file "$PROJECT_ROOT")" "${targets[@]}"
    fi

    local -a active_skills=()
    local -a stored_targets=()
    local -a state_args=()
    while IFS= read -r arg; do
        [[ -n "$arg" ]] && active_skills+=("$arg")
    done < <(skills_load_active_names "$PROJECT_ROOT")

    while IFS= read -r arg; do
        [[ -n "$arg" ]] && stored_targets+=("$arg")
    done < <(skills_load_targets "$PROJECT_ROOT")

    state_args=()
    if [[ "${#active_skills[@]}" -gt 0 ]]; then
        state_args+=("${active_skills[@]}")
    fi
    state_args+=("--targets")
    if [[ "${#stored_targets[@]}" -gt 0 ]]; then
        state_args+=("${stored_targets[@]}")
    fi
    skills_write_state_json "$PROJECT_ROOT" "${state_args[@]}"
    sync_to_targets
    echo -e "${GREEN}Skills synced.${NC}"
    if [[ "${#stored_targets[@]}" -gt 0 ]]; then
        echo "Targets: ${stored_targets[*]}"
    fi
}

command_standardize() {
    local timestamp backup_root bundle_path class file_path
    timestamp="$(date +"%Y%m%d-%H%M%S")"
    backup_root="$(skills_backup_dir "$PROJECT_ROOT")/$timestamp"
    bundle_path="$(skills_active_bundle_file "$PROJECT_ROOT")"

    mkdir -p "$backup_root"
    "$SCRIPT_DIR/build-active-skills.sh" "$PROJECT_ROOT" >/dev/null || true

    for file_path in \
        "$PROJECT_ROOT/CLAUDE.md" \
        "$PROJECT_ROOT/GEMINI.md" \
        "$PROJECT_ROOT/.cursorrules" \
        "$PROJECT_ROOT/.windsurfrules" \
        "$PROJECT_ROOT/.github/copilot-instructions.md" \
        "$PROJECT_ROOT/.ai/skills/ACTIVE_SKILLS.md" \
        "$PROJECT_ROOT/.ai/skills/active-skills.json"; do
        class="$(classify_file "$file_path")"
        case "$class" in
            canonical|legacy-appended)
                backup_file_if_present "$file_path" "$backup_root"
                ;;
            unknown-manual)
                echo -e "${YELLOW}Preserving manual file:${NC} $file_path"
                ;;
        esac
    done

    write_standardized_markers "$bundle_path"
    local -a active_skills=()
    local -a targets=()
    local -a state_args=()
    while IFS= read -r file_path; do
        [[ -n "$file_path" ]] && active_skills+=("$file_path")
    done < <(skills_load_active_names "$PROJECT_ROOT")
    while IFS= read -r file_path; do
        [[ -n "$file_path" ]] && targets+=("$file_path")
    done < <(skills_load_targets "$PROJECT_ROOT")

    state_args=()
    if [[ "${#active_skills[@]}" -gt 0 ]]; then
        state_args+=("${active_skills[@]}")
    fi
    state_args+=("--targets")
    if [[ "${#targets[@]}" -gt 0 ]]; then
        state_args+=("${targets[@]}")
    fi
    skills_write_state_json "$PROJECT_ROOT" "${state_args[@]}"

    if [[ -d "$backup_root" ]] && find "$backup_root" -type f | grep -q .; then
        echo -e "${GREEN}Standardization completed with backups:${NC} $backup_root"
    else
        rmdir "$backup_root" 2>/dev/null || true
        echo -e "${GREEN}Standardization completed.${NC}"
    fi
}

interactive_select() {
    local -a targets=()
    local -a skills=()
    local input selection

    echo -e "${BLUE}AI Shadow Vault - Skills Installer${NC}"
    echo "=================================="
    echo
    echo "Available targets:"
    local index=1 target
    while IFS= read -r target; do
        echo "  $index. $target"
        ((index++))
    done < <(supported_targets)

    echo
    echo "Presets: all native editors context"
    read -r -p "Targets (space-separated, preset, or 'all'): " input

    if [[ "$input" == "all" ]]; then
        while IFS= read -r target; do
            targets+=("$target")
        done < <(supported_targets)
    else
        for selection in $input; do
            if [[ "$selection" =~ ^[0-9]+$ ]]; then
                target="$(supported_targets | sed -n "${selection}p")"
                [[ -n "$target" ]] && targets+=("$target")
            else
                while IFS= read -r target; do
                    [[ -n "$target" ]] && targets+=("$target")
                done < <(resolve_requested_targets "$selection")
            fi
        done
    fi

    command_list
    echo
    read -r -p "Skills (space-separated or 'all'): " input

    if [[ "$input" == "all" ]]; then
        while IFS=$'\t' read -r selection _ _; do
            skills+=("$selection")
        done < <(skills_discover)
    else
        for selection in $input; do
            skills+=("$selection")
        done
    fi

    command_activate "${skills[@]}"
    command_sync "${targets[@]}"
}

usage() {
    cat <<EOF
Usage:
  vault-skills list
  vault-skills presets
  vault-skills status
  vault-skills activate [--preset <preset>] <skill> [skill...]
  vault-skills sync [target...|preset]
  vault-skills standardize

Targets:
  gemini codex claude cursor windsurf copilot junie opencode

Presets:
  all native editors context

Skill presets:
  planning reviewing reviewing-laravel reviewing-laravel-nova reviewing-filament laravel-nova filament tall-stack qa security frontend fullstack
EOF
}

main() {
    local command="${1:-interactive}"
    shift || true

    case "$command" in
        list)
            command_list
            ;;
        presets)
            command_presets
            ;;
        status)
            command_status
            ;;
        activate)
            [[ "$#" -gt 0 ]] || { echo -e "${RED}Provide at least one skill.${NC}"; exit 1; }
            command_activate "$@"
            ;;
        sync)
            command_sync "$@"
            ;;
        standardize)
            command_standardize
            ;;
        interactive)
            interactive_select
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
