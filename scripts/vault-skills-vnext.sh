#!/bin/bash

set -euo pipefail

# Re-exec once in a clean bash env to avoid login-shell hooks altering detection.
# Preserves only variables needed by this command behavior.
if [[ "${AI_SHADOW_SKILLS_CLEAN_ENV:-0}" != "1" ]]; then
    exec env -i \
        AI_SHADOW_SKILLS_CLEAN_ENV=1 \
        HOME="${HOME:-}" \
        PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:${PATH:-}" \
        PWD="$PWD" \
        TERM="${TERM:-xterm-256color}" \
        VAULT_SKILLS_NO_WRITE="${VAULT_SKILLS_NO_WRITE:-0}" \
        /bin/bash "$0" "$@"
fi

# Harden against shell wrappers/functions injected by environment hooks.
# This command should behave deterministically across interactive shells.
for _cmd in grep awk sort find sed tr; do
    unset -f "$_cmd" >/dev/null 2>&1 || true
done
PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vault-resolver.sh"
source "$SCRIPT_DIR/lib/skills-resolver.sh"

PROJECT_ROOT="$(vault_resolve_project_root "$PWD")"
AI_DIR="$PROJECT_ROOT/.ai"
SUGGESTIONS_FILE="$AI_DIR/skills/suggested-skills.md"
LEGACY_SKILLS_SCRIPT="$SCRIPT_DIR/install_skills.sh"
NO_WRITE="${VAULT_SKILLS_NO_WRITE:-0}"
AUTO_THRESHOLD="0.80"
SUGGEST_THRESHOLD="0.50"
PACK_RECOMMENDATIONS=()
STACK_SIGNAL_ROWS=()
SKILL_DISCOVERY_CACHE_LOADED=0
SKILL_DISCOVERY_ROWS=()
SKILL_LOOKUP_ROWS=()
CATALOG_CACHE_LOADED=0
CATALOG_HAS_DATA=0
CATALOG_GROUP_ROWS=()
CATALOG_SKILL_ROWS=()
CATALOG_PROFILE_AUTO_ROWS=()
CATALOG_PROFILE_SUGGEST_ROWS=()
CATALOG_SIGNAL_ROWS=()
CATALOG_WARNINGS_EMITTED=()

if [[ "$NO_WRITE" -ne 1 ]]; then
    mkdir -p "$AI_DIR/skills"
fi

to_unique_lines() {
    awk '!seen[$0]++'
}

load_skill_discovery_cache() {
    local skill_name skill_file skill_desc normalized_name

    if [[ "$SKILL_DISCOVERY_CACHE_LOADED" -eq 1 ]]; then
        return 0
    fi

    SKILL_DISCOVERY_CACHE_LOADED=1
    SKILL_DISCOVERY_ROWS=()
    SKILL_LOOKUP_ROWS=()

    while IFS=$'\t' read -r skill_name skill_file skill_desc; do
        [[ -n "$skill_name" ]] || continue
        normalized_name="$(skills_normalize_name "$skill_name")"
        SKILL_DISCOVERY_ROWS+=("$normalized_name|$skill_name|$skill_file|$skill_desc")
        SKILL_LOOKUP_ROWS+=("$normalized_name|$skill_name")
    done < <(skills_discover "$PROJECT_ROOT")
}

skill_cached_id() {
    local requested="${1:-}"
    local normalized_name row row_norm row_name

    normalized_name="$(skills_normalize_name "$requested")"
    load_skill_discovery_cache

    for row in "${SKILL_LOOKUP_ROWS[@]+"${SKILL_LOOKUP_ROWS[@]}"}"; do
        IFS='|' read -r row_norm row_name <<< "$row"
        if [[ "$row_norm" == "$normalized_name" ]]; then
            printf '%s\n' "$row_name"
            return 0
        fi
    done

    return 1
}

skill_exists() {
    local skill="$1"
    skill_cached_id "$skill" >/dev/null 2>&1
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

emit_entry() {
    local class="$1"
    local skill="$2"
    local signal="$3"
    local reason="$4"
    local confidence="$5"

    if skill_exists "$skill"; then
        printf '%s|%s|%s|%s|%s\n' "$class" "$skill" "$signal" "$reason" "$confidence"
    fi
}

add_pack_recommendation() {
    local pack="$1"
    local reason="$2"
    PACK_RECOMMENDATIONS+=("$pack|$reason")
}

catalog_warn_once() {
    local code="$1"
    local message="$2"
    local key="$code|$message"
    local existing

    for existing in "${CATALOG_WARNINGS_EMITTED[@]+"${CATALOG_WARNINGS_EMITTED[@]}"}"; do
        if [[ "$existing" == "$key" ]]; then
            return 0
        fi
    done

    CATALOG_WARNINGS_EMITTED+=("$key")
    echo "$code: $message" >&2
}

detect_stack_signals() {
    STACK_SIGNAL_ROWS=()

    if [[ -f "$PROJECT_ROOT/composer.json" ]]; then
        if grep -q '"laravel/framework"' "$PROJECT_ROOT/composer.json"; then
            STACK_SIGNAL_ROWS+=("composer:laravel-framework|composer.json: laravel/framework|Laravel framework dependency detected|1.00")
        fi
        if grep -q '"filament/filament"' "$PROJECT_ROOT/composer.json"; then
            STACK_SIGNAL_ROWS+=("composer:filament|composer.json: filament/filament|Filament dependency detected|1.00")
        fi
        if grep -q '"laravel/nova"' "$PROJECT_ROOT/composer.json"; then
            STACK_SIGNAL_ROWS+=("composer:nova|composer.json: laravel/nova|Laravel Nova dependency detected|1.00")
        fi
        if grep -q '"livewire/livewire"' "$PROJECT_ROOT/composer.json"; then
            STACK_SIGNAL_ROWS+=("composer:livewire|composer.json: livewire/livewire|Livewire dependency detected|1.00")
        fi
        if grep -q '"pestphp/pest"' "$PROJECT_ROOT/composer.json"; then
            STACK_SIGNAL_ROWS+=("composer:pest|composer.json: pestphp/pest|Pest test framework detected|1.00")
        fi
    fi

    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        if grep -q '"vue"' "$PROJECT_ROOT/package.json"; then
            STACK_SIGNAL_ROWS+=("package:vue|package.json: vue|Vue dependency detected|1.00")
        fi
        if grep -q '"primevue"' "$PROJECT_ROOT/package.json"; then
            STACK_SIGNAL_ROWS+=("package:primevue|package.json: primevue|PrimeVue dependency detected|1.00")
        fi
        if grep -q '"quasar"' "$PROJECT_ROOT/package.json"; then
            STACK_SIGNAL_ROWS+=("package:quasar|package.json: quasar|Quasar dependency detected|1.00")
        fi
    fi
}

stack_signal_requires_laravel_pack() {
    case "${1:-}" in
        composer:laravel-framework|composer:filament|composer:nova|composer:livewire|composer:pest)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

stack_has_laravel_pack_signal() {
    local row signal source reason confidence
    for row in "${STACK_SIGNAL_ROWS[@]+"${STACK_SIGNAL_ROWS[@]}"}"; do
        IFS='|' read -r signal source reason confidence <<< "$row"
        if stack_signal_requires_laravel_pack "$signal"; then
            return 0
        fi
    done
    return 1
}

catalog_parse_json() {
    local catalog_file="$1"

    if ! command -v python3 >/dev/null 2>&1; then
        return 1
    fi

    python3 - "$catalog_file" <<'PY'
import json
import os
import sys

catalog_file = sys.argv[1]

def clean(value):
    if value is None:
        return ""
    return str(value).replace("\t", " ").replace("\n", " ").strip()

with open(catalog_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

if not isinstance(data, dict):
    raise ValueError("catalog root must be an object")

if data.get("schema_version") != 1:
    raise ValueError("schema_version must be 1")

pack_name = clean(data.get("pack")) or clean(os.path.basename(os.path.dirname(catalog_file)))

groups = data.get("groups", [])
if not isinstance(groups, list):
    raise ValueError("groups must be an array")
for group in groups:
    if not isinstance(group, dict):
        continue
    group_id = clean(group.get("id"))
    if not group_id:
        continue
    group_label = clean(group.get("label")) or group_id
    print("\t".join(["GROUP", group_id, group_label, pack_name]))

skills = data.get("skills", [])
if not isinstance(skills, list):
    raise ValueError("skills must be an array")
for skill in skills:
    if not isinstance(skill, dict):
        continue
    skill_id = clean(skill.get("id"))
    skill_file = clean(skill.get("file"))
    group_id = clean(skill.get("group")) or "__NONE__"
    if not skill_id or not skill_file:
        raise ValueError("skills[] requires id and file")
    priority = skill.get("priority", 50)
    try:
        priority = int(priority)
    except Exception:
        priority = 50
    listable = "true" if bool(skill.get("listable", True)) else "false"
    description = clean(skill.get("description")) or "__NONE__"
    print("\t".join(["SKILL", skill_id, skill_file, group_id, str(priority), listable, description, pack_name]))

profiles = data.get("profiles", {})
if not isinstance(profiles, dict):
    raise ValueError("profiles must be an object")
for profile_id, profile in profiles.items():
    profile_id = clean(profile_id)
    if not profile_id or not isinstance(profile, dict):
        continue
    auto_items = profile.get("auto", []) or []
    suggest_items = profile.get("suggest", []) or []
    for token in auto_items:
        token = clean(token)
        if token:
            print("\t".join(["PROFILE_AUTO", profile_id, token, pack_name]))
    for token in suggest_items:
        token = clean(token)
        if token:
            print("\t".join(["PROFILE_SUGGEST", profile_id, token, pack_name]))

signal_profiles = data.get("signal_profiles", {})
if not isinstance(signal_profiles, dict):
    raise ValueError("signal_profiles must be an object")
for signal_id, profile_id in signal_profiles.items():
    signal_id = clean(signal_id)
    profile_id = clean(profile_id)
    if signal_id and profile_id:
        print("\t".join(["SIGNAL", signal_id, profile_id, pack_name]))
PY
}

load_catalog_cache() {
    local skills_root catalog_file parsed_rows row_type c1 c2 c3 c4 c5 c6 c7

    if [[ "$CATALOG_CACHE_LOADED" -eq 1 ]]; then
        return 0
    fi

    CATALOG_CACHE_LOADED=1
    CATALOG_HAS_DATA=0
    CATALOG_GROUP_ROWS=()
    CATALOG_SKILL_ROWS=()
    CATALOG_PROFILE_AUTO_ROWS=()
    CATALOG_PROFILE_SUGGEST_ROWS=()
    CATALOG_SIGNAL_ROWS=()

    while IFS= read -r skills_root; do
        [[ -n "$skills_root" ]] || continue
        catalog_file="$skills_root/catalog.json"

        if [[ ! -f "$catalog_file" ]]; then
            catalog_warn_once "ASV-CATALOG-001" "Missing pack catalog: $catalog_file. Falling back to built-in heuristics."
            continue
        fi

        if ! parsed_rows="$(catalog_parse_json "$catalog_file" 2>/dev/null)"; then
            catalog_warn_once "ASV-CATALOG-001" "Invalid pack catalog: $catalog_file. Falling back to built-in heuristics."
            continue
        fi

        while IFS=$'\t' read -r row_type c1 c2 c3 c4 c5 c6 c7; do
            [[ -n "$row_type" ]] || continue
            case "$row_type" in
                GROUP)
                    CATALOG_GROUP_ROWS+=("$c1|$c2|$c3")
                    ;;
                SKILL)
                    if [[ "$c3" == "__NONE__" ]]; then
                        c3=""
                    fi
                    if [[ "$c6" == "__NONE__" ]]; then
                        c6=""
                    fi
                    CATALOG_SKILL_ROWS+=("$c1|$c2|$c3|$c4|$c5|$c6|$c7")
                    ;;
                PROFILE_AUTO)
                    CATALOG_PROFILE_AUTO_ROWS+=("$c1|$c2|$c3")
                    ;;
                PROFILE_SUGGEST)
                    CATALOG_PROFILE_SUGGEST_ROWS+=("$c1|$c2|$c3")
                    ;;
                SIGNAL)
                    CATALOG_SIGNAL_ROWS+=("$c1|$c2|$c3")
                    ;;
            esac
        done <<< "$parsed_rows"
    done < <(skills_pack_catalog_roots "$PROJECT_ROOT")

    if [[ "${#CATALOG_SKILL_ROWS[@]}" -gt 0 ]]; then
        CATALOG_HAS_DATA=1
    fi
}

catalog_group_label() {
    local wanted_group="${1:-}"
    local row group_id group_label pack_name

    for row in "${CATALOG_GROUP_ROWS[@]+"${CATALOG_GROUP_ROWS[@]}"}"; do
        IFS='|' read -r group_id group_label pack_name <<< "$row"
        if [[ "$group_id" == "$wanted_group" ]]; then
            printf '%s\n' "$group_label"
            return 0
        fi
    done

    return 1
}

catalog_profile_tokens() {
    local wanted_profile="${1:-}"
    local wanted_pack="${2:-}"
    local mode="${3:-auto}"
    local row profile_id token pack_name

    if [[ "$mode" == "auto" ]]; then
        for row in "${CATALOG_PROFILE_AUTO_ROWS[@]+"${CATALOG_PROFILE_AUTO_ROWS[@]}"}"; do
            IFS='|' read -r profile_id token pack_name <<< "$row"
            if [[ "$profile_id" == "$wanted_profile" && "$pack_name" == "$wanted_pack" ]]; then
                printf '%s\n' "$token"
            fi
        done
        return 0
    fi

    for row in "${CATALOG_PROFILE_SUGGEST_ROWS[@]+"${CATALOG_PROFILE_SUGGEST_ROWS[@]}"}"; do
        IFS='|' read -r profile_id token pack_name <<< "$row"
        if [[ "$profile_id" == "$wanted_profile" && "$pack_name" == "$wanted_pack" ]]; then
            printf '%s\n' "$token"
        fi
    done
}

catalog_resolve_skill_id() {
    local catalog_skill_id="${1:-}"
    local catalog_skill_file="${2:-}"
    local fallback_id

    if [[ -n "$catalog_skill_id" ]]; then
        printf '%s\n' "$catalog_skill_id"
        return 0
    fi

    fallback_id="$(basename "${catalog_skill_file%.md}")"
    if [[ -n "$fallback_id" ]]; then
        printf '%s\n' "$fallback_id"
        return 0
    fi

    return 1
}

catalog_expand_token() {
    local token="${1:-}"
    local pack_name="${2:-}"
    local row skill_id skill_file group_id priority listable desc row_pack resolved_id

    if [[ "$token" == "*" ]]; then
        for row in "${CATALOG_SKILL_ROWS[@]+"${CATALOG_SKILL_ROWS[@]}"}"; do
            IFS='|' read -r skill_id skill_file group_id priority listable desc row_pack <<< "$row"
            [[ "$row_pack" == "$pack_name" ]] || continue
            [[ "$listable" == "true" ]] || continue
            printf '%s\n' "$(catalog_resolve_skill_id "$skill_id" "$skill_file")"
        done
        return 0
    fi

    for row in "${CATALOG_SKILL_ROWS[@]+"${CATALOG_SKILL_ROWS[@]}"}"; do
        IFS='|' read -r skill_id skill_file group_id priority listable desc row_pack <<< "$row"
        [[ "$row_pack" == "$pack_name" ]] || continue
        [[ "$skill_id" == "$token" ]] || continue
        [[ "$listable" == "true" ]] || continue
        printf '%s\n' "$(catalog_resolve_skill_id "$skill_id" "$skill_file")"
        return 0
    done

    printf '%s\n' "$(catalog_resolve_skill_id "$token" "$token.md")"
}

emit_catalog_detected_entries() {
    local signal_row signal_id signal_source signal_reason signal_confidence
    local signal_map_row map_signal profile_id pack_name token resolved_skill
    local emitted=0

    load_catalog_cache
    [[ "$CATALOG_HAS_DATA" -eq 1 ]] || return 1

    for signal_row in "${STACK_SIGNAL_ROWS[@]+"${STACK_SIGNAL_ROWS[@]}"}"; do
        IFS='|' read -r signal_id signal_source signal_reason signal_confidence <<< "$signal_row"

        for signal_map_row in "${CATALOG_SIGNAL_ROWS[@]+"${CATALOG_SIGNAL_ROWS[@]}"}"; do
            IFS='|' read -r map_signal profile_id pack_name <<< "$signal_map_row"
            [[ "$map_signal" == "$signal_id" ]] || continue

            while IFS= read -r token; do
                [[ -n "$token" ]] || continue
                while IFS= read -r resolved_skill; do
                    [[ -n "$resolved_skill" ]] || continue
                    printf '%s|%s|%s|%s|%s\n' \
                        "auto" \
                        "$resolved_skill" \
                        "$signal_source" \
                        "Catalog profile '$profile_id' matched by '$signal_id' (pack: $pack_name)" \
                        "$signal_confidence"
                    emitted=1
                done < <(catalog_expand_token "$token" "$pack_name")
            done < <(catalog_profile_tokens "$profile_id" "$pack_name" auto)

            while IFS= read -r token; do
                [[ -n "$token" ]] || continue
                while IFS= read -r resolved_skill; do
                    [[ -n "$resolved_skill" ]] || continue
                    printf '%s|%s|%s|%s|%s\n' \
                        "suggest" \
                        "$resolved_skill" \
                        "$signal_source" \
                        "Catalog profile '$profile_id' matched by '$signal_id' (pack: $pack_name)" \
                        "$signal_confidence"
                    emitted=1
                done < <(catalog_expand_token "$token" "$pack_name")
            done < <(catalog_profile_tokens "$profile_id" "$pack_name" suggest)
        done
    done

    [[ "$emitted" -eq 1 ]]
}

detect_pack_recommendations() {
    local deduped_pack=()
    local deduped_line
    local signal_row signal_id signal_source signal_reason signal_confidence

    PACK_RECOMMENDATIONS=()

    if vault_extension_is_enabled "$PROJECT_ROOT" "laravel" || vault_extension_is_enabled "$PROJECT_ROOT" "laravel-stack"; then
        return 0
    fi

    for signal_row in "${STACK_SIGNAL_ROWS[@]+"${STACK_SIGNAL_ROWS[@]}"}"; do
        IFS='|' read -r signal_id signal_source signal_reason signal_confidence <<< "$signal_row"
        case "$signal_id" in
            composer:laravel-framework)
                add_pack_recommendation "laravel" "Laravel framework detected"
                ;;
            composer:filament)
                add_pack_recommendation "laravel" "Filament package detected"
                ;;
            composer:nova)
                add_pack_recommendation "laravel" "Nova package detected"
                ;;
            composer:livewire)
                add_pack_recommendation "laravel" "Livewire package detected"
                ;;
            composer:pest)
                add_pack_recommendation "laravel" "Pest detected in PHP stack"
                ;;
        esac
    done

    if [[ "${#PACK_RECOMMENDATIONS[@]}" -gt 0 ]]; then
        while IFS= read -r deduped_line; do
            [[ -n "$deduped_line" ]] && deduped_pack+=("$deduped_line")
        done < <(printf '%s\n' "${PACK_RECOMMENDATIONS[@]}" | to_unique_lines)
        PACK_RECOMMENDATIONS=("${deduped_pack[@]}")
    fi
}

emit_detected_entries_heuristic() {
    if [[ -f "$PROJECT_ROOT/composer.json" ]]; then
        emit_entry suggest code-review "composer.json" "PHP dependency manifest detected" "0.72"
        emit_entry suggest qa-automation "composer.json" "Backend project likely benefits from test automation" "0.62"
        emit_entry suggest security-performance "composer.json" "Backend project likely benefits from security/performance review" "0.62"

        if grep -q '"laravel/framework"' "$PROJECT_ROOT/composer.json"; then
            emit_entry suggest dx-maintainer "composer.json: laravel/framework" "Laravel projects usually benefit from DX/lint automation" "0.68"
        fi

        if grep -q '"filament/filament"' "$PROJECT_ROOT/composer.json"; then
            emit_entry suggest frontend-expert "composer.json: filament/filament" "Filament admin panels often include frontend customization" "0.66"
        fi

        if grep -q '"laravel/nova"' "$PROJECT_ROOT/composer.json"; then
            :
        fi

        if grep -q '"livewire/livewire"' "$PROJECT_ROOT/composer.json"; then
            :
        fi

        if grep -q '"pestphp/pest"' "$PROJECT_ROOT/composer.json"; then
            emit_entry auto qa-automation "composer.json: pestphp/pest" "Pest test framework detected" "0.90"
        fi
    fi

    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        emit_entry suggest dx-maintainer "package.json" "JavaScript package manifest detected" "0.58"

        if grep -q '"vue"' "$PROJECT_ROOT/package.json"; then
            emit_entry auto frontend-expert "package.json: vue" "Vue dependency detected" "0.88"
            emit_entry suggest qa-automation "package.json: vue" "Frontend stack benefits from browser/integration tests" "0.67"
        fi

        if grep -q '"primevue"\|"quasar"' "$PROJECT_ROOT/package.json"; then
            emit_entry suggest frontend-expert "package.json: primevue/quasar" "UI framework detected" "0.73"
        fi
    fi

    if [[ -f "$PROJECT_ROOT/pyproject.toml" || -f "$PROJECT_ROOT/requirements.txt" ]]; then
        emit_entry suggest dx-maintainer "pyproject.toml/requirements.txt" "Python stack detected" "0.66"
        emit_entry suggest qa-automation "pyproject.toml/requirements.txt" "Python stack detected" "0.66"
        emit_entry suggest security-performance "pyproject.toml/requirements.txt" "Python stack detected" "0.66"
    fi

    if [[ -f "$PROJECT_ROOT/go.mod" ]]; then
        emit_entry suggest dx-maintainer "go.mod" "Go stack detected" "0.66"
        emit_entry suggest qa-automation "go.mod" "Go stack detected" "0.66"
        emit_entry suggest security-performance "go.mod" "Go stack detected" "0.66"
    fi
}

parse_detected_entries() {
    local decision_input

    DETECTED_AUTO=()
    DETECTED_SUGGEST=()
    DECISION_ROWS=()

    detect_stack_signals
    detect_pack_recommendations

    decision_input="$(emit_catalog_detected_entries || true)"
    if [[ -z "$decision_input" ]]; then
        decision_input="$(emit_detected_entries_heuristic || true)"
    fi

    while IFS='|' read -r decision skill signal reason confidence; do
        [[ -n "$decision" ]] || continue
        DECISION_ROWS+=("$decision|$skill|$signal|$reason|$confidence")
        if [[ "$decision" == "auto" ]]; then
            DETECTED_AUTO+=("$skill")
        elif [[ "$decision" == "suggest" ]]; then
            DETECTED_SUGGEST+=("$skill")
        fi
    done < <(
        printf '%s\n' "$decision_input" | awk -F'|' '
            function rank(decision) {
                if (decision == "auto") {
                    return 2
                }
                if (decision == "suggest") {
                    return 1
                }
                return 0
            }
            {
                decision=$1
                skill=$2
                conf=$5 + 0
                if (!(skill in best_decision) || rank(decision) > rank(best_decision[skill]) || (rank(decision) == rank(best_decision[skill]) && conf > best_conf[skill])) {
                    best_decision[skill]=decision
                    best_conf[skill]=conf
                    best_signal[skill]=$3
                    best_reason[skill]=$4
                }
            }
            END {
                for (skill in best_decision) {
                    conf=best_conf[skill]
                    decision=best_decision[skill]
                    printf "%s|%s|%s|%s|%.2f\n", decision, skill, best_signal[skill], best_reason[skill], conf
                }
            }
        ' | sort -t'|' -k1,1 -k5,5nr -k2,2
    )

    if [[ "${#DECISION_ROWS[@]}" -eq 0 ]]; then
        if skill_exists code-review; then
            DECISION_ROWS+=("suggest|code-review|fallback|No high-confidence stack signal detected|0.60")
            DETECTED_SUGGEST+=("code-review")
        fi
        if skill_exists dx-maintainer; then
            DECISION_ROWS+=("suggest|dx-maintainer|fallback|No high-confidence stack signal detected|0.55")
            DETECTED_SUGGEST+=("dx-maintainer")
        fi
    fi

    if [[ "${#DETECTED_AUTO[@]}" -gt 0 ]]; then
        local deduped_auto=()
        local deduped_line_auto
        while IFS= read -r deduped_line_auto; do
            [[ -n "$deduped_line_auto" ]] && deduped_auto+=("$deduped_line_auto")
        done < <(printf '%s\n' "${DETECTED_AUTO[@]}" | to_unique_lines)
        DETECTED_AUTO=("${deduped_auto[@]}")
    fi
    if [[ "${#DETECTED_SUGGEST[@]}" -gt 0 ]]; then
        local deduped_suggest=()
        local deduped_line_suggest
        while IFS= read -r deduped_line_suggest; do
            [[ -n "$deduped_line_suggest" ]] && deduped_suggest+=("$deduped_line_suggest")
        done < <(printf '%s\n' "${DETECTED_SUGGEST[@]}" | to_unique_lines)
        DETECTED_SUGGEST=("${deduped_suggest[@]}")
    fi

}

write_suggestions_file() {
    {
        echo "<!-- AI-SHADOW-VAULT: MANAGED FILE -->"
        echo
        echo "# Suggested Skills"
        echo
        echo "Generated from manifest detection with traceability and confidence scores."
        echo
        echo "Auto threshold: >= $AUTO_THRESHOLD"
        echo "Suggested threshold: >= $SUGGEST_THRESHOLD and < $AUTO_THRESHOLD"
        echo
        echo "## Detected"
        if [[ "${#DECISION_ROWS[@]}" -eq 0 ]]; then
            echo "- none"
        else
            local row decision skill signal reason confidence
            for row in "${DECISION_ROWS[@]}"; do
                IFS='|' read -r decision skill signal reason confidence <<< "$row"
                if [[ "$decision" == "auto" ]]; then
                    printf -- '- `%s` -> `%s` (auto-enabled, confidence: %s)\n' "$signal" "$skill" "$confidence"
                else
                    printf -- '- `%s` -> `%s` (suggested, confidence: %s)\n' "$signal" "$skill" "$confidence"
                fi
            done
        fi
        echo
        echo "## Why"
        if [[ "${#DECISION_ROWS[@]}" -eq 0 ]]; then
            echo "- none"
        else
            printf '%s\n' "${DECISION_ROWS[@]}" | while IFS='|' read -r decision skill signal reason confidence; do
                printf -- '- `%s`: %s\n' "$skill" "$reason"
            done | to_unique_lines
        fi
        echo
        echo "## Auto-Enable (High Confidence)"
        if [[ "${#DETECTED_AUTO[@]}" -eq 0 ]]; then
            echo "- none"
        else
            printf -- '- `%s`\n' "${DETECTED_AUTO[@]}"
        fi
        echo
        echo "## Suggested (Optional)"
        if [[ "${#DETECTED_SUGGEST[@]}" -eq 0 ]]; then
            echo "- none"
        else
            printf -- '- `%s`\n' "${DETECTED_SUGGEST[@]}"
        fi
        echo
        echo "## Pack Recommendations"
        if [[ "${#PACK_RECOMMENDATIONS[@]}" -eq 0 ]]; then
            echo "- none"
        else
            local rec pack reason
            for rec in "${PACK_RECOMMENDATIONS[@]}"; do
                IFS='|' read -r pack reason <<< "$rec"
                printf -- '- `%s`: %s. Install with `vault-ext enable %s`.\n' "$pack" "$reason" "$pack"
            done
        fi
    } > "$SUGGESTIONS_FILE"
}

print_suggest_human() {
    echo "Detected:"
    if [[ "${#DECISION_ROWS[@]}" -eq 0 ]]; then
        echo "- none"
    else
        local row decision skill signal reason confidence
        for row in "${DECISION_ROWS[@]}"; do
            IFS='|' read -r decision skill signal reason confidence <<< "$row"
            if [[ "$decision" == "auto" ]]; then
                printf -- '- %s -> %s (auto-enabled, confidence: %s)\n' "$signal" "$skill" "$confidence"
            else
                printf -- '- %s -> %s (suggested only, confidence: %s)\n' "$signal" "$skill" "$confidence"
            fi
        done
    fi

    echo
    echo "Why:"
    if [[ "${#DECISION_ROWS[@]}" -eq 0 ]]; then
        echo "- none"
    else
        printf '%s\n' "${DECISION_ROWS[@]}" | while IFS='|' read -r decision skill signal reason confidence; do
            printf -- '- %s\n' "$reason"
        done | to_unique_lines
    fi

    echo
    echo "Auto threshold: >= $AUTO_THRESHOLD"
    echo "Suggested threshold: >= $SUGGEST_THRESHOLD and < $AUTO_THRESHOLD"

    echo
    echo "Auto-enabled:"
    if [[ "${#DETECTED_AUTO[@]}" -eq 0 ]]; then
        echo "- none"
    else
        printf -- '- %s\n' "${DETECTED_AUTO[@]}"
    fi

    echo
    echo "Suggested:"
    if [[ "${#DETECTED_SUGGEST[@]}" -eq 0 ]]; then
        echo "- none"
    else
        printf -- '- %s\n' "${DETECTED_SUGGEST[@]}"
    fi

    echo
    echo "Pack recommendations:"
    if [[ "${#PACK_RECOMMENDATIONS[@]}" -eq 0 ]]; then
        echo "- none"
    else
        local rec pack reason
        for rec in "${PACK_RECOMMENDATIONS[@]}"; do
            IFS='|' read -r pack reason <<< "$rec"
            printf -- '- ASV-SUGGEST-PACK-001: %s. Recommended: vault-ext enable %s\n' "$reason" "$pack"
        done
    fi

}

print_suggest_plan() {
    local row decision skill signal reason confidence
    for row in "${DECISION_ROWS[@]}"; do
        IFS='|' read -r decision skill signal reason confidence <<< "$row"
        printf '%s|%s|%s\n' "$decision" "$skill" "$confidence"
    done
}

print_suggest_json() {
    local i row decision skill signal reason confidence

    echo '{'
    echo "  \"thresholds\": { \"auto\": $AUTO_THRESHOLD, \"suggest\": $SUGGEST_THRESHOLD },"
    echo '  "decisions": ['
    for ((i=0; i<${#DECISION_ROWS[@]}; i++)); do
        row="${DECISION_ROWS[$i]}"
        IFS='|' read -r decision skill signal reason confidence <<< "$row"
        printf '    { "signal": "%s", "skill": "%s", "decision": "%s", "confidence": %s, "reason": "%s" }' \
            "$(json_escape "$signal")" \
            "$(json_escape "$skill")" \
            "$(json_escape "$decision")" \
            "$confidence" \
            "$(json_escape "$reason")"
        if (( i < ${#DECISION_ROWS[@]} - 1 )); then
            echo ','
        else
            echo
        fi
    done
    echo '  ],'

    echo '  "auto": ['
    for ((i=0; i<${#DETECTED_AUTO[@]}; i++)); do
        printf '    "%s"' "$(json_escape "${DETECTED_AUTO[$i]}")"
        if (( i < ${#DETECTED_AUTO[@]} - 1 )); then
            echo ','
        else
            echo
        fi
    done
    echo '  ],'

    echo '  "suggested": ['
    for ((i=0; i<${#DETECTED_SUGGEST[@]}; i++)); do
        printf '    "%s"' "$(json_escape "${DETECTED_SUGGEST[$i]}")"
        if (( i < ${#DETECTED_SUGGEST[@]} - 1 )); then
            echo ','
        else
            echo
        fi
    done
    echo '  ]'
    echo '}'
}

print_skill_explanation() {
    local skill="$1"

    case "$skill" in
        qa-automation)
            cat <<'EOF_EXP'
Skill: qa-automation
What: Testing strategy and implementation guidance for unit, feature, integration, and browser tests.
Why: It keeps regressions visible and enforces safer iterative delivery.
Impact if ignored: Higher risk of silent regressions and unstable releases.
EOF_EXP
            ;;
        backend-expert)
            cat <<'EOF_EXP'
Skill: backend-expert
What: Production-ready Laravel/PHP backend implementation patterns.
Why: It standardizes robust architecture, typing, and security/performance defaults.
Impact if ignored: Inconsistent backend patterns, slower reviews, and higher defect risk.
EOF_EXP
            ;;
        frontend-expert)
            cat <<'EOF_EXP'
Skill: frontend-expert
What: Vue/admin-UI implementation patterns focused on maintainability and UX quality.
Why: It speeds delivery of coherent, reusable interfaces.
Impact if ignored: UI inconsistency, duplicated logic, and degraded UX.
EOF_EXP
            ;;
        dx-maintainer)
            cat <<'EOF_EXP'
Skill: dx-maintainer
What: Developer-experience and code-quality workflow guidance.
Why: It aligns linting, CI, and conventions across contributors.
Impact if ignored: More friction, style drift, and slower onboarding.
EOF_EXP
            ;;
        code-review)
            cat <<'EOF_EXP'
Skill: code-review
What: Structured review heuristics for defects, risk, and regression detection.
Why: It improves review signal-to-noise and consistency.
Impact if ignored: More escaped defects and uneven review depth.
EOF_EXP
            ;;
        *)
            local resolved
            resolved="$(skills_resolve_one "$skill" 2>/dev/null || true)"
            if [[ -z "$resolved" ]]; then
                return 1
            fi

            local resolved_name skill_file skill_desc
            IFS=$'\t' read -r resolved_name skill_file skill_desc <<< "$resolved"
            cat <<EOF_EXP
Skill: $resolved_name
What: ${skill_desc:-Specialized project skill guidance}.
Why: It provides focused best practices for a specific task domain.
Impact if ignored: Slower execution and less consistent quality in this domain.
EOF_EXP
            ;;
    esac
}

run_legacy() {
    "$LEGACY_SKILLS_SCRIPT" "$@"
}

ensure_required_pack_for_auto() {
    if vault_extension_is_enabled "$PROJECT_ROOT" "laravel" || vault_extension_is_enabled "$PROJECT_ROOT" "laravel-stack"; then
        return 0
    fi

    if ! stack_has_laravel_pack_signal; then
        return 0
    fi

    echo "ASV-AUTO-PACK-001: Laravel-related stack detected. Auto-enabling required pack: laravel"
    if ! "$SCRIPT_DIR/../bin/vault-ext" enable laravel; then
        echo "ASV-AUTO-PACK-001: Failed to auto-enable pack 'laravel'. Run: vault-ext enable laravel" >&2
        return 1
    fi

    SKILL_DISCOVERY_CACHE_LOADED=0
    CATALOG_CACHE_LOADED=0
    return 0
}

command_list() {
    local json_mode=0
    local group_filter=""
    local source_mode="pack"
    local rows=()
    local seen_ids=()
    local discovered_id skill_file skill_desc
    local normalized_id display_id group_id listable
    local catalog_row catalog_id catalog_file catalog_group catalog_priority catalog_listable catalog_desc catalog_pack
    local skill_key
    local group_name group_label row row_group row_id row_desc
    local groups=()
    local group_rows=()
    local i j idx

    while [[ "$#" -gt 0 ]]; do
        case "${1:-}" in
            --json)
                json_mode=1
                ;;
            --group)
                group_filter="${2:-}"
                [[ -n "$group_filter" ]] || { echo "Usage: vault-skills list [--json] [--group <id>] [--source pack|all]" >&2; exit 1; }
                shift
                ;;
            --source)
                source_mode="${2:-}"
                [[ "$source_mode" == "pack" || "$source_mode" == "all" ]] || {
                    echo "Invalid --source value: $source_mode (expected: pack|all)" >&2
                    exit 1
                }
                shift
                ;;
            *)
                echo "Unknown option for list: $1" >&2
                exit 1
                ;;
        esac
        shift
    done

    load_catalog_cache

    load_skill_discovery_cache

    for row in "${SKILL_DISCOVERY_ROWS[@]+"${SKILL_DISCOVERY_ROWS[@]}"}"; do
        IFS='|' read -r normalized_id discovered_id skill_file skill_desc <<< "$row"
        [[ -n "$discovered_id" ]] || continue

        if [[ "$source_mode" == "pack" && "$skill_file" == "$(skills_core_catalog_root)"/* ]]; then
            continue
        fi

        display_id="$discovered_id"
        group_id="uncategorized"
        listable="true"

        for catalog_row in "${CATALOG_SKILL_ROWS[@]+"${CATALOG_SKILL_ROWS[@]}"}"; do
            IFS='|' read -r catalog_id catalog_file catalog_group catalog_priority catalog_listable catalog_desc catalog_pack <<< "$catalog_row"
            if [[ "$(skills_normalize_name "$catalog_id")" == "$normalized_id" ]]; then
                display_id="$catalog_id"
                group_id="${catalog_group:-uncategorized}"
                listable="$catalog_listable"
                break
            fi
        done

        [[ "$listable" == "true" ]] || continue

        if [[ -n "$group_filter" && "$group_id" != "$group_filter" ]]; then
            continue
        fi

        skill_key="$(skills_normalize_name "$display_id")"
        if printf '%s\n' "${seen_ids[@]+"${seen_ids[@]}"}" | grep -qx "$skill_key"; then
            continue
        fi
        seen_ids+=("$skill_key")
        rows+=("$group_id|$display_id|$skill_desc")
    done

    while IFS= read -r group_name; do
        [[ -n "$group_name" ]] && groups+=("$group_name")
    done < <(printf '%s\n' "${rows[@]+"${rows[@]}"}" | awk -F'|' '{print $1}' | sort -u)

    if [[ "$json_mode" -eq 1 ]]; then
        echo '{'
        printf '  "source": "%s",\n' "$(json_escape "$source_mode")"
        printf '  "group_filter": "%s",\n' "$(json_escape "$group_filter")"
        printf '  "total": %d,\n' "${#rows[@]}"
        echo '  "groups": ['

        for ((i=0; i<${#groups[@]}; i++)); do
            group_name="${groups[$i]}"
            group_label="$(catalog_group_label "$group_name" || true)"
            [[ -n "$group_label" ]] || group_label="$group_name"

            group_rows=()
            while IFS= read -r row; do
                [[ -n "$row" ]] && group_rows+=("$row")
            done < <(printf '%s\n' "${rows[@]+"${rows[@]}"}" | awk -F'|' -v g="$group_name" '$1 == g' | sort -t'|' -k2,2)

            echo '    {'
            printf '      "id": "%s",\n' "$(json_escape "$group_name")"
            printf '      "label": "%s",\n' "$(json_escape "$group_label")"
            printf '      "count": %d,\n' "${#group_rows[@]}"
            echo '      "skills": ['

            for ((j=0; j<${#group_rows[@]}; j++)); do
                row="${group_rows[$j]}"
                IFS='|' read -r row_group row_id row_desc <<< "$row"
                printf '        { "id": "%s", "description": "%s" }' \
                    "$(json_escape "$row_id")" \
                    "$(json_escape "$row_desc")"
                if (( j < ${#group_rows[@]} - 1 )); then
                    echo ','
                else
                    echo
                fi
            done

            echo '      ]'
            if (( i < ${#groups[@]} - 1 )); then
                echo '    },'
            else
                echo '    }'
            fi
        done

        echo '  ]'
        echo '}'
        return
    fi

    echo "Available skills (source: $source_mode)"
    if [[ -n "$group_filter" ]]; then
        echo "Group filter: $group_filter"
    fi

    if [[ "${#rows[@]}" -eq 0 ]]; then
        echo "No skills available for current filters."
        return
    fi

    for group_name in "${groups[@]+"${groups[@]}"}"; do
        group_label="$(catalog_group_label "$group_name" || true)"
        [[ -n "$group_label" ]] || group_label="$group_name"

        group_rows=()
        while IFS= read -r row; do
            [[ -n "$row" ]] && group_rows+=("$row")
        done < <(printf '%s\n' "${rows[@]+"${rows[@]}"}" | awk -F'|' -v g="$group_name" '$1 == g' | sort -t'|' -k2,2)

        echo ""
        printf '%s [%s] (%d)\n' "$group_label" "$group_name" "${#group_rows[@]}"
        for row in "${group_rows[@]+"${group_rows[@]}"}"; do
            IFS='|' read -r row_group row_id row_desc <<< "$row"
            if [[ -n "$row_desc" ]]; then
                printf '  - %s: %s\n' "$row_id" "$row_desc"
            else
                printf '  - %s\n' "$row_id"
            fi
        done
    done

    echo ""
    echo "Total listable skills: ${#rows[@]}"
}

command_status() {
    run_legacy status
    echo ""
    if [[ -f "$SUGGESTIONS_FILE" ]]; then
        echo "Suggested skills file: $SUGGESTIONS_FILE"
    else
        echo "Suggested skills file not generated yet. Run: vault-skills suggest"
    fi
}

command_suggest() {
    local json_mode=0
    local plan_mode=0

    while [[ "$#" -gt 0 ]]; do
        case "${1:-}" in
            --json)
                json_mode=1
                ;;
            --plan)
                plan_mode=1
                ;;
            *)
                echo "Unknown option for suggest: $1" >&2
                exit 1
                ;;
        esac
        shift
    done

    parse_detected_entries

    if [[ "$NO_WRITE" -ne 1 ]]; then
        write_suggestions_file
    fi

    if [[ "$plan_mode" -eq 1 ]]; then
        print_suggest_plan
        return
    fi

    if [[ "$json_mode" -eq 1 ]]; then
        print_suggest_json
        return
    fi

    if [[ "$NO_WRITE" -ne 1 ]]; then
        echo "Wrote suggested skills to: $SUGGESTIONS_FILE"
        echo ""
    fi
    print_suggest_human
}

command_auto() {
    detect_stack_signals
    ensure_required_pack_for_auto
    parse_detected_entries

    if [[ "${#DETECTED_AUTO[@]}" -eq 0 ]]; then
        echo "No high-confidence skills detected."
        if [[ "$NO_WRITE" -ne 1 ]]; then
            write_suggestions_file
        fi
        return 0
    fi

    echo "Auto-enabling high-confidence skills: ${DETECTED_AUTO[*]}"
    run_legacy activate "${DETECTED_AUTO[@]}"
    if [[ "$NO_WRITE" -ne 1 ]]; then
        write_suggestions_file
    fi
}

command_set() {
    if [[ "$#" -eq 0 ]]; then
        echo "Usage: vault-skills set <skill> [skill...]" >&2
        exit 1
    fi

    run_legacy activate "$@"
    if [[ "$NO_WRITE" -ne 1 ]]; then
        parse_detected_entries
        write_suggestions_file
    fi
}

command_sync() {
    run_legacy sync "$@"
}

command_explain() {
    local skill="${1:-}"
    if [[ -z "$skill" ]]; then
        echo "Usage: vault-skills explain <skill-id>" >&2
        exit 1
    fi

    if ! print_skill_explanation "$skill"; then
        echo "Unknown skill: $skill" >&2
        echo "Tip: run 'vault-skills status' to inspect available/active skills." >&2
        exit 1
    fi
}

command_legacy() {
    run_legacy "$@"
}

subcommand="${1:-status}"
if [[ "$#" -gt 0 ]]; then
    shift
fi

case "$subcommand" in
    status)
        command_status "$@"
        ;;
    list)
        command_list "$@"
        ;;
    suggest)
        command_suggest "$@"
        ;;
    auto)
        command_auto "$@"
        ;;
    set)
        command_set "$@"
        ;;
    sync)
        command_sync "$@"
        ;;
    explain)
        command_explain "$@"
        ;;
    legacy)
        command_legacy "$@"
        ;;
    *)
        echo "Unknown command: $subcommand" >&2
        echo "Usage: vault-skills [status|list|suggest|auto|set|sync|explain|legacy]" >&2
        exit 1
        ;;
esac
