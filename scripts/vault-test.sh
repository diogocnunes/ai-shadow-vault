#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"

SUITE="quick"
SUITE_SET=0
RUN_ALL=0
JSON_MODE=0

while [[ "$#" -gt 0 ]]; do
    case "${1:-}" in
        --suite)
            SUITE="${2:-all}"
            SUITE_SET=1
            shift
            ;;
        --all)
            RUN_ALL=1
            ;;
        --json)
            JSON_MODE=1
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [[ "$SUITE_SET" -eq 0 && "$RUN_ALL" -eq 1 ]]; then
    SUITE="all"
fi

PASSED=0
FAILED=0
RESULT_LINES=()

record_result() {
    local status="$1"
    local name="$2"
    local message="$3"

    RESULT_LINES+=("$status|$name|$message")

    if [[ "$status" == "pass" ]]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
}

run_in_temp_project() {
    local callback="$1"
    local tmp_dir
    tmp_dir="$(mktemp -d /tmp/vault-test-XXXXXX)"

    mkdir -p "$tmp_dir/project"
    cd "$tmp_dir/project"
    git init -q

    "$callback" "$tmp_dir/project"
}

assert_file() {
    local file="$1"
    [[ -f "$file" ]]
}

suite_core() {
    run_in_temp_project _suite_core_inner
}

_suite_core_inner() {
    local root="$1"

    cat > "$root/composer.json" <<'JSON'
{"name":"demo/app","require":{"php":"^8.3"}}
JSON

    if AI_SHADOW_SKIP_GIT_SAFETY=1 "$BIN_DIR/vault-init" --non-interactive >/tmp/vault-test-core-init.log 2>&1; then
        if assert_file "$root/.ai/rules.md" && assert_file "$root/.ai/context/current-task.md" && assert_file "$root/.ai/context/project-context.md"; then
            record_result pass core "vault-init created canonical files"
        else
            record_result fail core "vault-init missing canonical files"
        fi
    else
        record_result fail core "vault-init failed"
    fi
}

suite_optimize() {
    run_in_temp_project _suite_optimize_inner
}

_suite_optimize_inner() {
    local root="$1"

    cat > "$root/composer.json" <<'JSON'
{"name":"demo/app","require":{"php":"^8.3","laravel/framework":"^11.0"}}
JSON

    cat > "$root/package.json" <<'JSON'
{"name":"demo","dependencies":{"vue":"^3.4.0"}}
JSON

    if AI_SHADOW_SKIP_GIT_SAFETY=1 "$BIN_DIR/vault-init" --optimize --non-interactive >/tmp/vault-test-optimize-init.log 2>&1; then
        if assert_file "$root/.ai/context/capabilities.json" && assert_file "$root/.ai/skills/suggested-skills.md"; then
            record_result pass optimize "optimize mode generated capabilities and skill suggestions"
        else
            record_result fail optimize "optimize mode missing capabilities or skill suggestions"
        fi
    else
        record_result fail optimize "vault-init --optimize failed"
    fi
}

extract_bootstrap_contract_block() {
    local claude_file="$1"

    awk '
        /^## Bootstrap Contract \(Mandatory\)$/ { in_block=1; next }
        in_block && /^## / { exit }
        in_block { print }
    ' "$claude_file"
}

suite_bootstrap() {
    run_in_temp_project _suite_bootstrap_inner
}

_suite_bootstrap_inner() {
    local root="$1"

    cat > "$root/package.json" <<'JSON'
{"name":"demo"}
JSON

    AI_SHADOW_SKIP_GIT_SAFETY=1 "$BIN_DIR/vault-init" --non-interactive >/tmp/vault-test-bootstrap-init.log 2>&1 || {
        record_result fail bootstrap "vault-init failed before bootstrap suite"
        return
    }

    if ! assert_file "$root/.ai/bootstrap.md"; then
        record_result fail bootstrap "vault-init did not generate .ai/bootstrap.md"
        return
    fi

    "$BIN_DIR/vault-bootstrap" ensure >/tmp/vault-test-bootstrap-ensure.log 2>&1 || {
        record_result fail bootstrap "vault-bootstrap ensure failed on healthy fixture"
        return
    }

    if ! grep -Eq '^- last_check: [0-9]{4}-[0-9]{2}-[0-9]{2}T' "$root/.ai/bootstrap.md"; then
        record_result fail bootstrap "bootstrap state missing successful last_check timestamp"
        return
    fi

    local contract_block
    contract_block="$(extract_bootstrap_contract_block "$root/CLAUDE.md")"
    if [[ -z "$contract_block" ]]; then
        record_result fail bootstrap "CLAUDE.md bootstrap contract block missing"
        return
    fi

    local line_count
    line_count="$(printf '%s\n' "$contract_block" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
    if (( line_count > 20 )); then
        record_result fail bootstrap "CLAUDE.md bootstrap contract exceeds 20 lines"
        return
    fi

    local line9='9. BOOTSTRAP_ACK is an audit signal only (not a guarantee of compliance).'
    local line10='10. Do not duplicate policy here; canonical policy is `.ai/rules.md`.'

    if ! grep -Fqx "$line9" <<< "$contract_block"; then
        record_result fail bootstrap "CLAUDE.md contract line 9 missing/reworded or outside contract block"
        return
    fi

    if ! grep -Fqx "$line10" <<< "$contract_block"; then
        record_result fail bootstrap "CLAUDE.md contract line 10 missing/reworded or outside contract block"
        return
    fi

    record_result pass bootstrap "bootstrap contract integrity and state ownership checks passed"
}

suite_task() {
    run_in_temp_project _suite_task_inner
}

_suite_task_inner() {
    local root="$1"

    cat > "$root/package.json" <<'JSON'
{"name":"demo"}
JSON

    AI_SHADOW_SKIP_GIT_SAFETY=1 "$BIN_DIR/vault-init" --non-interactive >/tmp/vault-test-task-init.log 2>&1 || {
        record_result fail task "vault-init failed before task suite"
        return
    }

    "$BIN_DIR/vault-task" quick "Validate task mode" --mode plan >/tmp/vault-test-task-new.log 2>&1 || {
        record_result fail task "vault-task quick failed"
        return
    }

    "$BIN_DIR/vault-task" mode execute >/tmp/vault-test-task-mode.log 2>&1 || {
        record_result fail task "vault-task mode failed"
        return
    }

    "$BIN_DIR/vault-task" done >/tmp/vault-test-task-done.log 2>&1 || {
        record_result fail task "vault-task done failed"
        return
    }

    local latest_archive
    latest_archive="$(ls -t "$root/.ai/archive/tasks"/*.md 2>/dev/null | head -n 1 || true)"
    if [[ -z "$latest_archive" ]]; then
        record_result fail task "task archive file not created"
        return
    fi

    if ! grep -q '^## Validation Instructions$' "$latest_archive" >/dev/null 2>&1; then
        record_result fail task "compiled task archive is missing Validation Instructions section"
        return
    fi

    if [[ -f "$latest_archive" ]]; then
        record_result pass task "task compile + done archived current task with structured sections"
    else
        record_result fail task "task archive file not created"
    fi
}

suite_migration() {
    run_in_temp_project _suite_migration_inner
}

_suite_migration_inner() {
    local root="$1"

    cat > "$root/package.json" <<'JSON'
{"name":"demo"}
JSON

    AI_SHADOW_SKIP_GIT_SAFETY=1 "$BIN_DIR/vault-init" --non-interactive >/tmp/vault-test-mig-init.log 2>&1 || {
        record_result fail migration "vault-init failed before migration suite"
        return
    }

    mkdir -p "$root/.ai/context/archive"
    echo "legacy" > "$root/.ai/context/archive/legacy.md"

    "$BIN_DIR/vault-doctor" --check migration --fix >/tmp/vault-test-mig-doctor.log 2>&1 || true

    if [[ -f "$root/.ai/archive/legacy.md" || -f "$root/.ai/archive/context/archive/legacy.md" ]]; then
        record_result pass migration "legacy archive content migrated"
    else
        if [[ -f "$root/.ai/archive/legacy.md" ]]; then
            record_result pass migration "legacy archive content migrated"
        else
            record_result fail migration "legacy archive content not migrated"
        fi
    fi
}

suite_doctor() {
    run_in_temp_project _suite_doctor_inner
}

_suite_doctor_inner() {
    local root="$1"

    cat > "$root/package.json" <<'JSON'
{"name":"demo"}
JSON

    AI_SHADOW_SKIP_GIT_SAFETY=1 "$BIN_DIR/vault-init" --non-interactive >/tmp/vault-test-doctor-init.log 2>&1 || {
        record_result fail doctor "vault-init failed before doctor suite"
        return
    }

    if "$BIN_DIR/vault-doctor" >/tmp/vault-test-doctor.log 2>&1; then
        record_result pass doctor "vault-doctor passed on healthy fixture"
    else
        record_result fail doctor "vault-doctor reported errors on healthy fixture"
    fi
}

run_selected_suites() {
    case "$SUITE" in
        quick)
            suite_core
            suite_bootstrap
            suite_doctor
            ;;
        core)
            suite_core
            ;;
        optimize)
            suite_optimize
            ;;
        task)
            suite_task
            ;;
        doctor)
            suite_doctor
            ;;
        bootstrap)
            suite_bootstrap
            ;;
        skills)
            suite_optimize
            ;;
        migration)
            suite_migration
            ;;
        all)
            suite_core
            suite_optimize
            suite_bootstrap
            suite_task
            suite_migration
            suite_doctor
            ;;
        *)
            echo "Unknown suite: $SUITE" >&2
            exit 1
            ;;
    esac
}

print_human() {
    local line status name message
    for line in "${RESULT_LINES[@]}"; do
        IFS='|' read -r status name message <<< "$line"
        echo "[$status] $name - $message"
    done
    echo
    echo "Summary: passed=$PASSED failed=$FAILED"
}

print_json() {
    local line status name message

    echo '{'
    echo "  \"summary\": { \"passed\": $PASSED, \"failed\": $FAILED },"
    echo '  "results": ['

    local i=0
    local total=${#RESULT_LINES[@]}
    for line in "${RESULT_LINES[@]}"; do
        IFS='|' read -r status name message <<< "$line"
        esc_message=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '    { "status": "%s", "suite": "%s", "message": "%s" }' "$status" "$name" "$esc_message"
        i=$((i + 1))
        if (( i < total )); then
            echo ','
        else
            echo
        fi
    done

    echo '  ]'
    echo '}'
}

run_selected_suites

if [[ "$JSON_MODE" -eq 1 ]]; then
    print_json
else
    print_human
fi

if (( FAILED > 0 )); then
    exit 1
fi
