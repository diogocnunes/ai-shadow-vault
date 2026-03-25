set -euo pipefail

BOOTSTRAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BOOTSTRAP_LIB_DIR/vault-resolver.sh"

BOOTSTRAP_REPO_ROOT="$(cd "$BOOTSTRAP_LIB_DIR/../.." && pwd)"
BOOTSTRAP_TEMPLATES_DIR="$BOOTSTRAP_REPO_ROOT/templates/.ai"
BOOTSTRAP_RULES_TEMPLATE="$BOOTSTRAP_TEMPLATES_DIR/rules.md"
BOOTSTRAP_FILE_TEMPLATE="$BOOTSTRAP_TEMPLATES_DIR/bootstrap.md"
BOOTSTRAP_CLAUDE_TEMPLATE="$BOOTSTRAP_REPO_ROOT/templates/CLAUDE.md"

bootstrap_project_root() {
    vault_resolve_project_root "${1:-$PWD}"
}

bootstrap_ai_dir() {
    local project_root="$1"
    printf '%s\n' "$project_root/.ai"
}

bootstrap_state_file() {
    local project_root="$1"
    printf '%s\n' "$project_root/.ai/bootstrap.md"
}

bootstrap_capabilities_file() {
    local project_root="$1"
    printf '%s\n' "$project_root/.ai/context/capabilities.json"
}

bootstrap_warning_block() {
    local remediation="$1"
    shift || true

    echo ""
    echo "⚠️  BOOTSTRAP INVALID"
    echo "------------------------------------------"
    if [[ "$#" -eq 0 ]]; then
        echo "- Unknown bootstrap validation failure."
    else
        local item
        for item in "$@"; do
            echo "- $item"
        done
    fi
    echo "- Action: STOP and REPORT (no task execution)."
    echo "- Remediation: $remediation"
    echo "------------------------------------------"
}

bootstrap_write_capabilities_file() {
    local project_root="$1"
    local cap_file
    cap_file="$(bootstrap_capabilities_file "$project_root")"

    mkdir -p "$(dirname "$cap_file")"

    local has_rtk=0
    local has_gemini=0
    local has_context7=0

    command -v rtk >/dev/null 2>&1 && has_rtk=1
    command -v gemini >/dev/null 2>&1 && has_gemini=1
    command -v context7 >/dev/null 2>&1 && has_context7=1

    cat > "$cap_file" <<EOF_CAP
{
  "generated_by": "vault-bootstrap",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "capabilities": {
    "rtk": { "available": $has_rtk, "required": false },
    "gemini_cli": { "available": $has_gemini, "required": false },
    "context7": { "available": $has_context7, "required": false }
  },
  "fallback_policy": "Missing optional tools must not block vault operation."
}
EOF_CAP
}

bootstrap_refresh_agent_context() {
    local project_root="$1"
    local script_path="$BOOTSTRAP_REPO_ROOT/scripts/vault-ai-context-file.sh"

    if [[ -x "$script_path" ]]; then
        (
            cd "$project_root"
            BOOTSTRAP_RUNNING=1 "$script_path" >/dev/null
        )
        return $?
    fi

    return 1
}

bootstrap_copy_if_missing() {
    local src="$1"
    local dst="$2"

    if [[ -f "$dst" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

bootstrap_validate_required_files() {
    local project_root="$1"

    local rules_file="$project_root/.ai/rules.md"
    local agent_context_file="$project_root/.ai/context/agent-context.md"

    if [[ ! -f "$rules_file" ]]; then
        printf '%s\n' "Missing required file: .ai/rules.md"
    elif [[ ! -r "$rules_file" ]]; then
        printf '%s\n' "Required file is not readable: .ai/rules.md"
    fi

    if [[ ! -f "$agent_context_file" ]]; then
        printf '%s\n' "Missing required file: .ai/context/agent-context.md"
    elif [[ ! -r "$agent_context_file" ]]; then
        printf '%s\n' "Required file is not readable: .ai/context/agent-context.md"
    fi
}

bootstrap_validate_contract_markers() {
    local project_root="$1"

    local claude_file="$project_root/CLAUDE.md"

    if [[ ! -f "$claude_file" ]]; then
        printf '%s\n' "Missing adapter file: CLAUDE.md"
        return
    fi

    local line9='9. BOOTSTRAP_ACK is an audit signal only (not a guarantee of compliance).'
    local line10='10. Do not duplicate policy here; canonical policy is `.ai/rules.md`.'

    local contract_block
    contract_block="$(awk '
        /^## Bootstrap Contract \(Mandatory\)$/ { in_block=1; next }
        in_block && /^## / { exit }
        in_block { print }
    ' "$claude_file")"

    if [[ -z "$contract_block" ]]; then
        printf '%s\n' "Missing Bootstrap Contract block in CLAUDE.md"
        return
    fi

    if ! grep -Fqx "$line9" <<< "$contract_block"; then
        printf '%s\n' "CLAUDE.md contract line 9 missing/reworded or outside contract block"
    fi

    if ! grep -Fqx "$line10" <<< "$contract_block"; then
        printf '%s\n' "CLAUDE.md contract line 10 missing/reworded or outside contract block"
    fi
}

bootstrap_contract_block_is_valid() {
    local claude_file="$1"
    local line9='9. BOOTSTRAP_ACK is an audit signal only (not a guarantee of compliance).'
    local line10='10. Do not duplicate policy here; canonical policy is `.ai/rules.md`.'
    local contract_block

    [[ -f "$claude_file" ]] || return 1

    contract_block="$(awk '
        /^## Bootstrap Contract \(Mandatory\)$/ { in_block=1; next }
        in_block && /^## / { exit }
        in_block { print }
    ' "$claude_file")"

    [[ -n "$contract_block" ]] || return 1
    grep -Fqx "$line9" <<< "$contract_block" || return 1
    grep -Fqx "$line10" <<< "$contract_block" || return 1
    return 0
}

bootstrap_sync_claude_contract_if_needed() {
    local project_root="$1"
    local claude_file="$project_root/CLAUDE.md"

    [[ -f "$BOOTSTRAP_CLAUDE_TEMPLATE" ]] || return 0

    if [[ ! -f "$claude_file" ]]; then
        cp "$BOOTSTRAP_CLAUDE_TEMPLATE" "$claude_file"
        return 0
    fi

    if bootstrap_contract_block_is_valid "$claude_file"; then
        return 0
    fi

    if grep -q '^<!-- AI-SHADOW-VAULT: MANAGED FILE -->' "$claude_file"; then
        cp "$BOOTSTRAP_CLAUDE_TEMPLATE" "$claude_file"
    fi
}

bootstrap_write_state_file() {
    local project_root="$1"
    local last_result="$2"
    local rules_status="$3"
    local context_status="$4"
    local capabilities_status="$5"
    local state_file
    state_file="$(bootstrap_state_file "$project_root")"

    mkdir -p "$(dirname "$state_file")"

    # Ownership: bootstrap-enforcer is the only writer of `last_check`.
    cat > "$state_file" <<EOF_STATE
<!-- AI-SHADOW-VAULT: MANAGED FILE -->

# Bootstrap State
- Canonical policy: \`.ai/rules.md\`
- Primary enforcement surface: \`CLAUDE.md\`
- rules.md: $rules_status
- agent-context.md: $context_status
- capabilities.json: $capabilities_status
- last_check: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- last_result: $last_result
- remediation: \`vault-bootstrap ensure\`
- guard: \`BOOTSTRAP_RUNNING=1\` disables nested checks
EOF_STATE
}

bootstrap_collect_statuses() {
    local project_root="$1"

    local rules_file="$project_root/.ai/rules.md"
    local context_file="$project_root/.ai/context/agent-context.md"
    local caps_file
    caps_file="$(bootstrap_capabilities_file "$project_root")"
    local rules_status="missing"
    local context_status="missing"
    local caps_status="absent"

    if [[ -f "$rules_file" && -r "$rules_file" ]]; then
        rules_status="ok"
    fi

    if [[ -f "$context_file" && -r "$context_file" ]]; then
        context_status="ok"
    fi

    if [[ -f "$caps_file" ]]; then
        caps_status="present"
    fi

    printf '%s\t%s\t%s\n' "$rules_status" "$context_status" "$caps_status"
}

bootstrap_log_ack() {
    local project_root="$1"
    local source_label="${2:-unknown}"
    local log_file="$project_root/.ai/archive/bootstrap-ack.log"

    mkdir -p "$(dirname "$log_file")"
    printf '%s | %s | %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$source_label" "BOOTSTRAP_ACK: rules+context loaded" >> "$log_file"
}

bootstrap_run_check() {
    local start_dir="${1:-$PWD}"
    local quiet="${2:-0}"
    local project_root ai_dir
    local errors=()
    local validation_error

    if [[ "${BOOTSTRAP_RUNNING:-0}" == "1" ]]; then
        return 0
    fi

    project_root="$(bootstrap_project_root "$start_dir")"
    ai_dir="$(bootstrap_ai_dir "$project_root")"

    if [[ ! -d "$ai_dir" ]]; then
        errors+=("Missing .ai directory in project root")
    else
        while IFS= read -r validation_error; do
            [[ -n "$validation_error" ]] && errors+=("$validation_error")
        done < <(bootstrap_validate_required_files "$project_root")
        while IFS= read -r validation_error; do
            [[ -n "$validation_error" ]] && errors+=("$validation_error")
        done < <(bootstrap_validate_contract_markers "$project_root")
    fi

    if [[ "${#errors[@]}" -gt 0 ]]; then
        if [[ "$quiet" -ne 1 ]]; then
            bootstrap_warning_block "vault-bootstrap ensure" "${errors[@]}"
        fi
        return 1
    fi

    return 0
}

bootstrap_run_ensure() {
    local start_dir="${1:-$PWD}"
    local quiet="${2:-0}"
    local project_root ai_dir state_file caps_file rules_status context_status caps_status
    local previous_guard="${BOOTSTRAP_RUNNING:-}"
    local errors=()
    local validation_error

    if [[ "${BOOTSTRAP_RUNNING:-0}" == "1" ]]; then
        return 0
    fi

    project_root="$(bootstrap_project_root "$start_dir")"
    ai_dir="$(bootstrap_ai_dir "$project_root")"
    state_file="$(bootstrap_state_file "$project_root")"
    caps_file="$(bootstrap_capabilities_file "$project_root")"

    export BOOTSTRAP_RUNNING=1

    if [[ ! -d "$ai_dir" ]]; then
        errors+=("Missing .ai directory in project root")
    else
        if [[ -f "$BOOTSTRAP_FILE_TEMPLATE" ]]; then
            bootstrap_copy_if_missing "$BOOTSTRAP_FILE_TEMPLATE" "$state_file"
        fi

        if [[ ! -f "$project_root/.ai/rules.md" && -f "$BOOTSTRAP_RULES_TEMPLATE" ]]; then
            bootstrap_copy_if_missing "$BOOTSTRAP_RULES_TEMPLATE" "$project_root/.ai/rules.md"
        fi

        bootstrap_sync_claude_contract_if_needed "$project_root"

        if [[ ! -f "$project_root/.ai/context/agent-context.md" ]]; then
            bootstrap_refresh_agent_context "$project_root" || true
        fi

        if [[ ! -f "$caps_file" ]]; then
            bootstrap_write_capabilities_file "$project_root"
        fi

        while IFS= read -r validation_error; do
            [[ -n "$validation_error" ]] && errors+=("$validation_error")
        done < <(bootstrap_validate_required_files "$project_root")
        while IFS= read -r validation_error; do
            [[ -n "$validation_error" ]] && errors+=("$validation_error")
        done < <(bootstrap_validate_contract_markers "$project_root")
    fi

    IFS=$'\t' read -r rules_status context_status caps_status < <(bootstrap_collect_statuses "$project_root")

    if [[ "${#errors[@]}" -gt 0 ]]; then
        bootstrap_write_state_file "$project_root" "invalid" "$rules_status" "$context_status" "$caps_status"
        if [[ "$quiet" -ne 1 ]]; then
            bootstrap_warning_block "vault-bootstrap ensure" "${errors[@]}"
        fi

        if [[ -n "$previous_guard" ]]; then
            export BOOTSTRAP_RUNNING="$previous_guard"
        else
            unset BOOTSTRAP_RUNNING
        fi
        return 1
    fi

    bootstrap_write_state_file "$project_root" "valid" "$rules_status" "$context_status" "$caps_status"

    if [[ -n "$previous_guard" ]]; then
        export BOOTSTRAP_RUNNING="$previous_guard"
    else
        unset BOOTSTRAP_RUNNING
    fi

    return 0
}
