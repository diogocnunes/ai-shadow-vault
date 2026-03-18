vault_mm_start_marker() {
    local section="$1"
    printf '<!-- AI_SHADOW_VAULT:START:%s -->' "$section"
}

vault_mm_end_marker() {
    local section="$1"
    printf '<!-- AI_SHADOW_VAULT:END:%s -->' "$section"
}

vault_mm_has_any_section() {
    local file_path="$1"
    [ -f "$file_path" ] || return 1
    grep -Eq '^<!-- AI_SHADOW_VAULT:START:[a-z0-9-]+ -->$' "$file_path"
}

vault_mm_has_section() {
    local file_path="$1"
    local section="$2"
    local start_marker end_marker

    [ -f "$file_path" ] || return 1

    start_marker="$(vault_mm_start_marker "$section")"
    end_marker="$(vault_mm_end_marker "$section")"

    grep -Fqx "$start_marker" "$file_path" && grep -Fqx "$end_marker" "$file_path"
}

vault_mm_trim_file_end() {
    local file_path="$1"
    local tmp_file

    tmp_file="$(mktemp)"
    awk '
        {
            lines[++count] = $0
        }

        END {
            while (count > 0 && lines[count] == "") {
                count--
            }

            for (i = 1; i <= count; i++) {
                print lines[i]
            }
        }
    ' "$file_path" > "$tmp_file"

    mv "$tmp_file" "$file_path"
}

vault_mm_remove_section() {
    local file_path="$1"
    local section="$2"
    local start_marker end_marker tmp_file

    [ -f "$file_path" ] || return 0

    start_marker="$(vault_mm_start_marker "$section")"
    end_marker="$(vault_mm_end_marker "$section")"

    tmp_file="$(mktemp)"
    awk -v start_marker="$start_marker" -v end_marker="$end_marker" '
        $0 == start_marker { in_section = 1; next }
        in_section && $0 == end_marker { in_section = 0; next }
        !in_section { print }
    ' "$file_path" > "$tmp_file"

    mv "$tmp_file" "$file_path"
    vault_mm_trim_file_end "$file_path"
}

vault_mm_append_section_once() {
    local file_path="$1"
    local section="$2"
    local section_content="$3"
    local start_marker end_marker

    [ -f "$file_path" ] || return 1

    if vault_mm_has_section "$file_path" "$section"; then
        return 0
    fi

    start_marker="$(vault_mm_start_marker "$section")"
    end_marker="$(vault_mm_end_marker "$section")"

    vault_mm_trim_file_end "$file_path"

    {
        printf '\n%s\n' "$start_marker"
        printf '%s\n' "$section_content"
        printf '%s\n\n' "$end_marker"
    } >> "$file_path"
}

vault_mm_upsert_section() {
    local file_path="$1"
    local section="$2"
    local section_content="$3"

    [ -f "$file_path" ] || return 1

    vault_mm_remove_section "$file_path" "$section"
    vault_mm_append_section_once "$file_path" "$section" "$section_content"
}

vault_mm_extract_first_section_content() {
    local file_path="$1"
    local section="$2"
    local start_marker end_marker

    [ -f "$file_path" ] || return 1

    start_marker="$(vault_mm_start_marker "$section")"
    end_marker="$(vault_mm_end_marker "$section")"

    awk -v start_marker="$start_marker" -v end_marker="$end_marker" '
        $0 == start_marker && !capturing { capturing = 1; next }
        capturing && $0 == end_marker { found = 1; exit }
        capturing { print }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "$file_path"
}
