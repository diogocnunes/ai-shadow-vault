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

if [[ "$NO_WRITE" -ne 1 ]]; then
    mkdir -p "$AI_DIR/skills"
fi

to_unique_lines() {
    awk '!seen[$0]++'
}

skill_exists() {
    local skill="$1"
    skills_resolve_one "$skill" >/dev/null 2>&1
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

detect_pack_recommendations() {
    local deduped_pack=()
    local deduped_line

    PACK_RECOMMENDATIONS=()

    if vault_extension_is_enabled "$PROJECT_ROOT" "laravel" || vault_extension_is_enabled "$PROJECT_ROOT" "laravel-stack"; then
        return 0
    fi

    if [[ -f "$PROJECT_ROOT/composer.json" ]]; then
        if grep -q '"laravel/framework"' "$PROJECT_ROOT/composer.json"; then
            add_pack_recommendation "laravel" "Laravel framework detected"
        fi
        if grep -q '"filament/filament"' "$PROJECT_ROOT/composer.json"; then
            add_pack_recommendation "laravel" "Filament package detected"
        fi
        if grep -q '"laravel/nova"' "$PROJECT_ROOT/composer.json"; then
            add_pack_recommendation "laravel" "Nova package detected"
        fi
        if grep -q '"livewire/livewire"' "$PROJECT_ROOT/composer.json"; then
            add_pack_recommendation "laravel" "Livewire package detected"
        fi
    fi

    if [[ "${#PACK_RECOMMENDATIONS[@]}" -gt 0 ]]; then
        while IFS= read -r deduped_line; do
            [[ -n "$deduped_line" ]] && deduped_pack+=("$deduped_line")
        done < <(printf '%s\n' "${PACK_RECOMMENDATIONS[@]}" | to_unique_lines)
        PACK_RECOMMENDATIONS=("${deduped_pack[@]}")
    fi
}

emit_detected_entries() {
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
    DETECTED_AUTO=()
    DETECTED_SUGGEST=()
    DECISION_ROWS=()
    detect_pack_recommendations

    while IFS='|' read -r decision skill signal reason confidence; do
        [[ -n "$decision" ]] || continue
        DECISION_ROWS+=("$decision|$skill|$signal|$reason|$confidence")
        if [[ "$decision" == "auto" ]]; then
            DETECTED_AUTO+=("$skill")
        elif [[ "$decision" == "suggest" ]]; then
            DETECTED_SUGGEST+=("$skill")
        fi
    done < <(
        emit_detected_entries | awk -F'|' -v auto_cutoff="$AUTO_THRESHOLD" -v suggest_cutoff="$SUGGEST_THRESHOLD" '
            {
                skill=$2
                conf=$5 + 0
                if (!(skill in best_conf) || conf > best_conf[skill]) {
                    best_conf[skill]=conf
                    best_signal[skill]=$3
                    best_reason[skill]=$4
                }
            }
            END {
                for (skill in best_conf) {
                    conf=best_conf[skill]
                    decision="ignore"
                    if (conf >= auto_cutoff) {
                        decision="auto"
                    } else if (conf >= suggest_cutoff) {
                        decision="suggest"
                    }
                    if (decision != "ignore") {
                        printf "%s|%s|%s|%s|%.2f\n", decision, skill, best_signal[skill], best_reason[skill], conf
                    }
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
    parse_detected_entries

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
        echo "Usage: vault-skills [status|suggest|auto|set|sync|explain|legacy]" >&2
        exit 1
        ;;
esac
