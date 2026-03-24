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

    cat <<'EOF_COMPILE' | "$BIN_DIR/vault-task" compile --stdin --apply --mode execute >/tmp/vault-test-task-compile.log 2>&1 || {
Dado que ação @app/Nova/Actions/Absence/ApproveReject.php apresenta textos não traduzidos, gostaria que fossem alterados os termos hardcoded em português para inglês e que os textos fossem adicionados para @lang/vendor/nova/pt.json.
Para testar, aceder via Playwright a http://sigmmp.test e clicar em 'Aceder via Janus'.
Não modificar outros componentes.
EOF_COMPILE
        record_result fail task "vault-task compile failed"
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

    if ! grep -q '@app/Nova/Actions/Absence/ApproveReject.php' "$latest_archive" >/dev/null 2>&1; then
        record_result fail task "compiled task archive did not preserve @ file references"
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
        skills)
            suite_optimize
            ;;
        migration)
            suite_migration
            ;;
        all)
            suite_core
            suite_optimize
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
