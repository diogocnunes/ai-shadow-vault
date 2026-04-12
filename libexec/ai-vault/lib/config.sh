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

    py="$(ai_vault_python)" || return 1

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
PY
}

ai_vault_write_config() {
    local base_path="$1"
    local adapters_csv="$2"
    local rtk_enabled="$3"
    local config_dir config_file py

    config_dir="$(ai_vault_config_dir)"
    config_file="$(ai_vault_config_file)"
    py="$(ai_vault_python)" || return 1

    mkdir -p "$config_dir"

    BASE_PATH="$base_path" ADAPTERS_CSV="$adapters_csv" RTK_ENABLED="$rtk_enabled" CONFIG_FILE="$config_file" "$py" <<'PY'
import json
import os

adapters = [item for item in os.environ["ADAPTERS_CSV"].split(",") if item]
payload = {
    "vault_base_path": os.path.expanduser(os.environ["BASE_PATH"]),
    "default_adapters": adapters,
    "extras": {
        "rtk_instructions": os.environ["RTK_ENABLED"] == "1",
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

    py="$(ai_vault_python)" || return 1

    "$py" - "$config_file" <<'PY'
import json
import os
import shlex
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

base = os.path.expanduser(data["vault_base_path"])
adapters = "\n".join(data["default_adapters"])
rtk = "1" if data["extras"]["rtk_instructions"] else "0"

print(f"AI_VAULT_CONFIG_BASE_PATH={shlex.quote(base)}")
print(f"AI_VAULT_CONFIG_ADAPTERS={shlex.quote(adapters)}")
print(f"AI_VAULT_CONFIG_RTK_INSTRUCTIONS={shlex.quote(rtk)}")
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
