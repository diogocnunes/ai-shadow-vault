set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/bootstrap-enforcer.sh"

usage() {
    cat <<'USAGE'
Usage:
  vault-bootstrap ensure [--quiet|--json]
  vault-bootstrap check [--quiet|--json]
  vault-bootstrap ack [--source <label>]
USAGE
}

print_json_result() {
    local ok_value="$1"
    if [[ "$ok_value" -eq 1 ]]; then
        echo '{"ok":true}'
    else
        echo '{"ok":false}'
    fi
}

subcommand="${1:-ensure}"
shift || true

quiet=0
json=0
source_label="unknown"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --quiet)
            quiet=1
            ;;
        --json)
            json=1
            ;;
        --source)
            source_label="${2:-unknown}"
            shift
            ;;
        -h|--help|help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift || true
done

case "$subcommand" in
    ensure)
        if bootstrap_run_ensure "$PWD" "$quiet"; then
            [[ "$json" -eq 1 ]] && print_json_result 1
            exit 0
        fi
        [[ "$json" -eq 1 ]] && print_json_result 0
        exit 1
        ;;
    check)
        if bootstrap_run_check "$PWD" "$quiet"; then
            [[ "$json" -eq 1 ]] && print_json_result 1
            exit 0
        fi
        [[ "$json" -eq 1 ]] && print_json_result 0
        exit 1
        ;;
    ack)
        project_root="$(bootstrap_project_root "$PWD")"
        bootstrap_log_ack "$project_root" "$source_label"
        [[ "$json" -eq 1 ]] && print_json_result 1
        ;;
    *)
        echo "Unknown subcommand: $subcommand" >&2
        usage
        exit 1
        ;;
esac
