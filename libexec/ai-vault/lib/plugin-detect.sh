#!/bin/bash

detect_plugins_from_names() {
    local names="$1"
    local prefix="$2"
    local has_superpowers=0
    local has_context_mode=0
    local has_adhd=0
    local line normalized

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        normalized="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
        [[ "$normalized" == "superpowers" || "$normalized" == *":superpowers" ]] && has_superpowers=1
        [[ "$normalized" == "context-mode" || "$normalized" == *":context-mode" || "$normalized" == "context_mode" || "$normalized" == *":context_mode" ]] && has_context_mode=1
        [[ "$normalized" == "i-have-adhd" || "$normalized" == *":i-have-adhd" ]] && has_adhd=1
    done < <(printf '%s\n' "$names")

    printf '%s_HAS_SUPERPOWERS=%s\n' "$prefix" "$has_superpowers"
    printf '%s_HAS_CONTEXT_MODE=%s\n' "$prefix" "$has_context_mode"
    printf '%s_HAS_ADHD=%s\n' "$prefix" "$has_adhd"
}

detect_claude_plugins() {
    local plugins_file="$HOME/.claude/plugins/installed_plugins.json"
    local py names

    [[ -f "$plugins_file" ]] || {
        printf 'CLAUDE_HAS_SUPERPOWERS=0\nCLAUDE_HAS_CONTEXT_MODE=0\n'
        return
    }

    py="$(command -v python3 || true)"
    if [[ -n "$py" ]]; then
        names="$("$py" - "$plugins_file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {}

plugins = data.get("plugins", {}) if isinstance(data, dict) else {}
if isinstance(plugins, dict):
    for key in plugins.keys():
        if isinstance(key, str):
            print(key.split("@", 1)[0])
PY
)"
    else
        names="$(grep -Eo '"[^"]+"\s*:' "$plugins_file" | sed -E 's/"([^"]+)".*/\1/' | cut -d'@' -f1)"
    fi

    detect_plugins_from_names "$names" "CLAUDE"
}

detect_codex_plugins() {
    local py names

    py="$(command -v python3 || true)"
    if [[ -n "$py" ]]; then
        names="$("$py" - <<'PY'
import json
from pathlib import Path

root = Path.home() / ".codex" / "plugins" / "cache"
if root.exists():
    for path in root.rglob("plugin.json"):
        if ".codex-plugin/plugin.json" not in str(path):
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if isinstance(data, dict):
            name = data.get("name")
            if isinstance(name, str):
                print(name)
PY
)"
    else
        names="$(
            {
                find "$HOME/.codex/plugins/cache" -type f -path '*/.codex-plugin/plugin.json' 2>/dev/null || true
            } | while IFS= read -r file; do
                if command -v jq >/dev/null 2>&1; then
                    jq -r '.name // empty' "$file" 2>/dev/null
                else
                    # best-effort fallback without jq/python
                    grep -E '"name"[[:space:]]*:[[:space:]]*"' "$file" \
                        | head -n 1 \
                        | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
                fi
            done
        )"
    fi

    detect_plugins_from_names "$names" "CODEX"
}

detect_opencode_plugins() {
    local config_file="$HOME/.config/opencode/opencode.json"
    local py names

    [[ -f "$config_file" ]] || {
        printf 'OPENCODE_HAS_SUPERPOWERS=0\nOPENCODE_HAS_CONTEXT_MODE=0\n'
        return
    }

    py="$(command -v python3 || true)"
    if [[ -n "$py" ]]; then
        names="$("$py" - "$config_file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    data = {}

plugins = data.get("plugin", [])
if isinstance(plugins, list):
    for item in plugins:
        if isinstance(item, str):
            print(item.split("@", 1)[0])
PY
)"
    else
        names="$(
            tr -d '\n' <"$config_file" \
                | grep -Eo '"plugin"[[:space:]]*:[[:space:]]*\[[^]]*\]' \
                | tr ',' '\n' \
                | sed -E 's/.*"([^"]+)".*/\1/' \
                | cut -d'@' -f1
        )"
    fi

    detect_plugins_from_names "$names" "OPENCODE"
}

detect_gemini_plugins() {
    local py names

    py="$(command -v python3 || true)"
    if [[ -n "$py" ]]; then
        names="$("$py" - <<'PY'
import json
from pathlib import Path

root = Path.home() / ".gemini" / "extensions"
if not root.exists():
    raise SystemExit(0)

for ext_dir in root.iterdir():
    if not ext_dir.is_dir():
        continue
    for filename in ("gemini-extension.json", "package.json"):
        path = ext_dir / filename
        if not path.is_file():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if isinstance(data, dict) and isinstance(data.get("name"), str):
            print(data["name"])
            break
PY
)"
    else
        names="$(
            for ext_dir in "$HOME/.gemini/extensions"/*/; do
                [[ -d "$ext_dir" ]] || continue
                file=""
                if [[ -f "$ext_dir/gemini-extension.json" ]]; then
                    file="$ext_dir/gemini-extension.json"
                elif [[ -f "$ext_dir/package.json" ]]; then
                    file="$ext_dir/package.json"
                fi
                [[ -n "$file" ]] || continue
                grep -E '"name"[[:space:]]*:[[:space:]]*"' "$file" \
                    | head -n 1 \
                    | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
            done
        )"
    fi

    detect_plugins_from_names "$names" "GEMINI"
}

_parse_detected_plugins() {
    local prefix="$1"
    local output="$2"
    local has_superpowers=0 has_context_mode=0 has_adhd=0
    local key value

    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        case "$key" in
            "${prefix}_HAS_SUPERPOWERS") has_superpowers="$value" ;;
            "${prefix}_HAS_CONTEXT_MODE") has_context_mode="$value" ;;
            "${prefix}_HAS_ADHD") has_adhd="$value" ;;
        esac
    done <<< "$output"

    printf '%s %s %s\n' "$has_superpowers" "$has_context_mode" "$has_adhd"
}

detect_plugins_for_adapter() {
    local adapter_name="$1"
    local out has_superpowers has_context_mode has_adhd

    case "$adapter_name" in
        CLAUDE.md)
            out="$(detect_claude_plugins)"
            read -r has_superpowers has_context_mode has_adhd <<< "$(_parse_detected_plugins "CLAUDE" "$out")"
            HAS_SUPERPOWERS_CLAUDE="${has_superpowers:-0}"
            HAS_CONTEXT_MODE_CLAUDE="${has_context_mode:-0}"
            HAS_ADHD_CLAUDE="${has_adhd:-0}"
            true
            ;;
        AGENTS.md)
            out="$(detect_codex_plugins)"
            read -r has_superpowers has_context_mode has_adhd <<< "$(_parse_detected_plugins "CODEX" "$out")"
            local codex_superpowers="${has_superpowers:-0}" codex_context_mode="${has_context_mode:-0}"

            out="$(detect_opencode_plugins)"
            read -r has_superpowers has_context_mode has_adhd <<< "$(_parse_detected_plugins "OPENCODE" "$out")"
            HAS_SUPERPOWERS_AGENTS=0
            HAS_CONTEXT_MODE_AGENTS=0
            HAS_ADHD_AGENTS=0
            [[ "$codex_superpowers" -eq 1 || "${has_superpowers:-0}" -eq 1 ]] && HAS_SUPERPOWERS_AGENTS=1
            [[ "$codex_context_mode" -eq 1 || "${has_context_mode:-0}" -eq 1 ]] && HAS_CONTEXT_MODE_AGENTS=1
            true
            ;;
        GEMINI.md)
            out="$(detect_gemini_plugins)"
            read -r has_superpowers has_context_mode has_adhd <<< "$(_parse_detected_plugins "GEMINI" "$out")"
            HAS_SUPERPOWERS_GEMINI="${has_superpowers:-0}"
            HAS_CONTEXT_MODE_GEMINI="${has_context_mode:-0}"
            HAS_ADHD_GEMINI=0
            true
            ;;
    esac
}

detect_all_plugins() {
    local adapter_name

    HAS_SUPERPOWERS_ANY=0
    for adapter_name in "${ADAPTER_NAMES[@]}"; do
        detect_plugins_for_adapter "$adapter_name"
    done

    if [[ "$HAS_SUPERPOWERS_CLAUDE" -eq 1 || "$HAS_SUPERPOWERS_AGENTS" -eq 1 || "$HAS_SUPERPOWERS_GEMINI" -eq 1 ]]; then
        HAS_SUPERPOWERS_ANY=1
    fi
}
