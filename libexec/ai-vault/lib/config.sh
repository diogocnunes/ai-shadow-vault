#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ai_vault_config_dir() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/ai-shadow-vault"
}

ai_vault_config_file() {
    printf '%s/config.json\n' "$(ai_vault_config_dir)"
}

ai_vault_config_exists() {
    [[ -f "$(ai_vault_config_file)" ]]
}

ai_vault_default_base_path() {
    printf '%s/.ai-shadow-vault-data\n' "$HOME"
}

ai_vault_detect_base_path_candidates() {
    local candidate
    local -a candidates=()

    candidates+=("$(ai_vault_default_base_path)")

    for candidate in \
        "$HOME"/Library/CloudStorage/GoogleDrive-* \
        "$HOME/Library/CloudStorage/Dropbox" \
        "$HOME/Dropbox" \
        "$HOME/Google Drive"; do
        [[ -d "$candidate" ]] || continue
        candidates+=("$candidate/ai-shadow-vault")
    done

    printf '%s\n' "${candidates[@]}" | awk '!seen[$0]++'
}

ai_vault_validate_config() {
    local config_file="${1:-$(ai_vault_config_file)}"
    local py

    py="$(command -v python3 || true)"
    if [[ -z "$py" ]]; then
        ai_vault_export_config_fallback "$config_file" >/dev/null || return 1
        return 0
    fi

    "$py" - "$config_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

base = data.get("vault_base_path")
adapters = data.get("default_adapters")
extras = data.get("extras")

if not isinstance(base, str) or not base.strip():
    raise SystemExit("Invalid config: vault_base_path must be a non-empty string.")

if not isinstance(adapters, list) or not adapters:
    raise SystemExit("Invalid config: default_adapters must be a non-empty array.")

allowed = {"CLAUDE.md", "AGENTS.md", "GEMINI.md"}
for item in adapters:
    if item not in allowed:
        raise SystemExit(f"Invalid config: unsupported adapter '{item}'.")

if not isinstance(extras, dict):
    raise SystemExit("Invalid config: extras must be an object.")

rtk = extras.get("rtk_instructions")
if not isinstance(rtk, bool):
    raise SystemExit("Invalid config: extras.rtk_instructions must be a boolean.")

for key in (
    "superpowers_instructions",
    "context_mode_instructions",
    "use_superpowers_docs",
    "adhd_instructions",
):
    value = extras.get(key, False)
    if not isinstance(value, bool):
        raise SystemExit(f"Invalid config: extras.{key} must be a boolean.")
PY
}

_ai_vault_parse_bool_key() {
    local file="$1"
    local key="$2"
    awk -v key="$key" '
        match($0, "\"" key "\"[[:space:]]*:[[:space:]]*") {
            line = $0
            sub("^[[:space:]]*\"" key "\"[[:space:]]*:[[:space:]]*", "", line)
            sub(/[[:space:],}].*$/, "", line)
            print line
            exit
        }
    ' "$file"
}

ai_vault_export_config_fallback() {
    local config_file="$1"
    local base adapters_csv
    local rtk_enabled superpowers_enabled context_mode_enabled use_superpowers_docs adhd_enabled

    [[ -f "$config_file" ]] || {
        ai_vault_error "Missing config: $config_file"
        return 1
    }

    base="$(
        awk '
            /"vault_base_path"[[:space:]]*:/ {
                line = $0
                sub(/^[[:space:]]*"vault_base_path"[[:space:]]*:[[:space:]]*"/, "", line)
                sub(/".*$/, "", line)
                print line
                exit
            }
        ' "$config_file" | sed 's/\\"/"/g'
    )"
    adapters_csv="$(
        awk '
            /"default_adapters"[[:space:]]*:/ { in_array = 1 }
            in_array {
                while (match($0, /"[^"]+"/)) {
                    value = substr($0, RSTART + 1, RLENGTH - 2)
                    if (value != "default_adapters") {
                        if (out != "") {
                            out = out "\n"
                        }
                        out = out value
                    }
                    $0 = substr($0, RSTART + RLENGTH)
                }
                if ($0 ~ /\]/) {
                    in_array = 0
                }
            }
            END { print out }
        ' "$config_file"
    )"
    rtk_enabled="$(_ai_vault_parse_bool_key "$config_file" "rtk_instructions")"
    superpowers_enabled="$(_ai_vault_parse_bool_key "$config_file" "superpowers_instructions")"
    context_mode_enabled="$(_ai_vault_parse_bool_key "$config_file" "context_mode_instructions")"
    use_superpowers_docs="$(_ai_vault_parse_bool_key "$config_file" "use_superpowers_docs")"
    adhd_enabled="$(_ai_vault_parse_bool_key "$config_file" "adhd_instructions")"

    if [[ -z "$base" || -z "$adapters_csv" ]]; then
        ai_vault_error "Invalid config: unable to parse $config_file without python3."
        return 1
    fi

    case "$rtk_enabled" in
        true) rtk_enabled="1" ;;
        false) rtk_enabled="0" ;;
        "") rtk_enabled="0" ;;
        *)
            ai_vault_error "Invalid config: extras.rtk_instructions must be a boolean."
            return 1
            ;;
    esac
    case "$superpowers_enabled" in
        true) superpowers_enabled="1" ;;
        false|"") superpowers_enabled="0" ;;
        *)
            ai_vault_error "Invalid config: extras.superpowers_instructions must be a boolean."
            return 1
            ;;
    esac
    case "$context_mode_enabled" in
        true) context_mode_enabled="1" ;;
        false|"") context_mode_enabled="0" ;;
        *)
            ai_vault_error "Invalid config: extras.context_mode_instructions must be a boolean."
            return 1
            ;;
    esac
    case "$use_superpowers_docs" in
        true) use_superpowers_docs="1" ;;
        false|"") use_superpowers_docs="0" ;;
        *)
            ai_vault_error "Invalid config: extras.use_superpowers_docs must be a boolean."
            return 1
            ;;
    esac
    case "$adhd_enabled" in
        true) adhd_enabled="1" ;;
        false|"") adhd_enabled="0" ;;
        *)
            ai_vault_error "Invalid config: extras.adhd_instructions must be a boolean."
            return 1
            ;;
    esac

    while IFS= read -r adapter; do
        case "$adapter" in
            CLAUDE.md|AGENTS.md|GEMINI.md) ;;
            *)
                ai_vault_error "Invalid config: unsupported adapter '$adapter'."
                return 1
                ;;
        esac
    done < <(printf '%s\n' "$adapters_csv")

    printf 'AI_VAULT_CONFIG_BASE_PATH=%q\n' "$base"
    printf 'AI_VAULT_CONFIG_ADAPTERS=%q\n' "$adapters_csv"
    printf 'AI_VAULT_CONFIG_RTK_INSTRUCTIONS=%q\n' "$rtk_enabled"
    printf 'AI_VAULT_CONFIG_SUPERPOWERS_INSTRUCTIONS=%q\n' "$superpowers_enabled"
    printf 'AI_VAULT_CONFIG_CONTEXT_MODE_INSTRUCTIONS=%q\n' "$context_mode_enabled"
    printf 'AI_VAULT_CONFIG_USE_SUPERPOWERS_DOCS=%q\n' "$use_superpowers_docs"
    printf 'AI_VAULT_CONFIG_ADHD_INSTRUCTIONS=%q\n' "$adhd_enabled"
}

ai_vault_write_config() {
    local base_path="$1"
    local adapters_csv="$2"
    local rtk_enabled="$3"
    local superpowers_enabled="$4"
    local context_mode_enabled="$5"
    local use_superpowers_docs="$6"
    local adhd_enabled="${7:-0}"
    local config_dir config_file py

    config_dir="$(ai_vault_config_dir)"
    config_file="$(ai_vault_config_file)"
    py="$(ai_vault_python)" || return 1

    mkdir -p "$config_dir"

    BASE_PATH="$base_path" ADAPTERS_CSV="$adapters_csv" RTK_ENABLED="$rtk_enabled" SUPERPOWERS_ENABLED="$superpowers_enabled" CONTEXT_MODE_ENABLED="$context_mode_enabled" USE_SUPERPOWERS_DOCS="$use_superpowers_docs" ADHD_ENABLED="$adhd_enabled" CONFIG_FILE="$config_file" "$py" <<'PY'
import json
import os

adapters = [item for item in os.environ["ADAPTERS_CSV"].split(",") if item]
payload = {
    "vault_base_path": os.path.expanduser(os.environ["BASE_PATH"]),
    "default_adapters": adapters,
    "extras": {
        "rtk_instructions": os.environ["RTK_ENABLED"] == "1",
        "superpowers_instructions": os.environ["SUPERPOWERS_ENABLED"] == "1",
        "context_mode_instructions": os.environ["CONTEXT_MODE_ENABLED"] == "1",
        "use_superpowers_docs": os.environ["USE_SUPERPOWERS_DOCS"] == "1",
        "adhd_instructions": os.environ["ADHD_ENABLED"] == "1",
    },
}

with open(os.environ["CONFIG_FILE"], "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}

ai_vault_export_config() {
    local config_file="${1:-$(ai_vault_config_file)}"
    local py

    py="$(command -v python3 || true)"
    if [[ -z "$py" ]]; then
        ai_vault_export_config_fallback "$config_file"
        return
    fi

    "$py" - "$config_file" <<'PY'
import json
import os
import shlex
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

base = os.path.expanduser(data["vault_base_path"])
adapters = "\n".join(data["default_adapters"])
extras = data.get("extras", {})
rtk = "1" if extras.get("rtk_instructions", False) else "0"
superpowers = "1" if extras.get("superpowers_instructions", False) else "0"
context_mode = "1" if extras.get("context_mode_instructions", False) else "0"
use_superpowers_docs = "1" if extras.get("use_superpowers_docs", False) else "0"
adhd = "1" if extras.get("adhd_instructions", False) else "0"

print(f"AI_VAULT_CONFIG_BASE_PATH={shlex.quote(base)}")
print(f"AI_VAULT_CONFIG_ADAPTERS={shlex.quote(adapters)}")
print(f"AI_VAULT_CONFIG_RTK_INSTRUCTIONS={shlex.quote(rtk)}")
print(f"AI_VAULT_CONFIG_SUPERPOWERS_INSTRUCTIONS={shlex.quote(superpowers)}")
print(f"AI_VAULT_CONFIG_CONTEXT_MODE_INSTRUCTIONS={shlex.quote(context_mode)}")
print(f"AI_VAULT_CONFIG_USE_SUPERPOWERS_DOCS={shlex.quote(use_superpowers_docs)}")
print(f"AI_VAULT_CONFIG_ADHD_INSTRUCTIONS={shlex.quote(adhd)}")
PY
}

ai_vault_load_config() {
    local config_file="${1:-$(ai_vault_config_file)}"
    local export_file

    [[ -f "$config_file" ]] || {
        ai_vault_error "Missing config: $config_file"
        return 1
    }

    ai_vault_validate_config "$config_file" || return 1
    export_file="$(mktemp)"
    ai_vault_export_config "$config_file" >"$export_file"
    # shellcheck disable=SC1090
    source "$export_file"
    rm -f "$export_file"
}

ai_vault_install_mode() {
    if ai_vault_is_git_install; then
        printf '%s\n' "git"
        return
    fi

    if command -v brew >/dev/null 2>&1 && brew list ai-vault >/dev/null 2>&1; then
        printf '%s\n' "homebrew"
        return
    fi

    printf '%s\n' "package"
}
