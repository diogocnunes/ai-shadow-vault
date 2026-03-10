#!/bin/sh

vault_primary_data_root() {
    printf '%s\n' "$HOME/.ai-shadow-vault-data"
}

vault_legacy_data_root() {
    printf '%s\n' "$HOME/.gemini-vault"
}

vault_ensure_data_root() {
    local primary_root legacy_root
    primary_root=$(vault_primary_data_root)
    legacy_root=$(vault_legacy_data_root)

    if [ -d "$legacy_root" ] && [ ! -e "$primary_root" ]; then
        if mv "$legacy_root" "$primary_root" 2>/dev/null; then
            printf '%s\n' "$primary_root"
        else
            printf '%s\n' "$legacy_root"
        fi
        return
    fi

    if [ ! -d "$primary_root" ] && [ ! -d "$legacy_root" ]; then
        mkdir -p "$primary_root"
    fi

    printf '%s\n' "$primary_root"
}

vault_git_toplevel() {
    local start_dir
    start_dir=${1:-"$PWD"}

    git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null
}

vault_git_common_dir() {
    local start_dir
    start_dir=${1:-"$PWD"}

    git -C "$start_dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

vault_git_origin_url() {
    local start_dir
    start_dir=${1:-"$PWD"}

    git -C "$start_dir" config --get remote.origin.url 2>/dev/null
}

vault_normalize_repo_url() {
    local repo_url normalized
    repo_url=$1

    if [ -z "$repo_url" ]; then
        return 1
    fi

    normalized=$(printf '%s\n' "$repo_url" | sed -E \
        -e 's#^(git\+ssh|ssh|git|https?)://##' \
        -e 's#^[^@]+@##' \
        -e 's#:#/#1' \
        -e 's#^/##' \
        -e 's#\.git$##' \
        -e 's#/$##')

    case "$normalized" in
        */*/*)
            printf '%s\n' "$normalized"
            return 0
            ;;
    esac

    return 1
}

vault_resolve_project_root() {
    local start_dir git_root current_dir
    start_dir=${1:-"$PWD"}

    git_root=$(vault_git_toplevel "$start_dir")
    if [ -n "$git_root" ]; then
        printf '%s\n' "$git_root"
        return
    fi

    current_dir=$start_dir
    while [ "$current_dir" != "/" ]; do
        if [ -d "$current_dir/.git" ] || [ -f "$current_dir/composer.json" ] || [ -f "$current_dir/package.json" ]; then
            printf '%s\n' "$current_dir"
            return
        fi
        current_dir=$(dirname "$current_dir")
    done

    printf '%s\n' "$start_dir"
}

vault_resolve_project_key() {
    local start_dir origin_url
    start_dir=${1:-"$PWD"}

    origin_url=$(vault_git_origin_url "$start_dir")
    if [ -n "$origin_url" ]; then
        vault_normalize_repo_url "$origin_url" && return 0
    fi

    return 1
}

vault_resolve_project_slug() {
    local start_dir project_key common_dir common_root git_root
    start_dir=${1:-"$PWD"}

    project_key=$(vault_resolve_project_key "$start_dir")
    if [ -n "$project_key" ]; then
        basename "$project_key"
        return
    fi

    common_dir=$(vault_git_common_dir "$start_dir")
    if [ -n "$common_dir" ] && [ "$common_dir" != "." ]; then
        common_root=$(dirname "$common_dir")
        if [ -n "$common_root" ] && [ "$common_root" != "." ]; then
            basename "$common_root"
            return
        fi
    fi

    git_root=$(vault_git_toplevel "$start_dir")
    if [ -n "$git_root" ]; then
        basename "$git_root"
        return
    fi

    basename "$start_dir"
}

vault_find_base() {
    local primary_root legacy_root
    primary_root=$(vault_ensure_data_root)
    legacy_root=$(vault_legacy_data_root)

    if [ -d "$primary_root/by-repo" ]; then
        printf '%s\n' "$primary_root/by-repo"
        return
    fi

    if [ -d "$primary_root" ]; then
        if [ -z "$(find "$primary_root" -mindepth 1 -maxdepth 1 ! -name by-repo -print -quit 2>/dev/null)" ]; then
            printf '%s\n' "$primary_root/by-repo"
            return
        fi
        printf '%s\n' "$primary_root"
        return
    fi

    if [ -d "$legacy_root/by-repo" ]; then
        printf '%s\n' "$legacy_root/by-repo"
        return
    fi

    if [ -d "$legacy_root" ]; then
        printf '%s\n' "$legacy_root"
        return
    fi

    printf '%s\n' "$primary_root/by-repo"
}

vault_shared_asset_path() {
    local relative_path primary_root legacy_root
    relative_path=$1
    primary_root=$(vault_primary_data_root)
    legacy_root=$(vault_legacy_data_root)

    if [ -e "$primary_root/$relative_path" ]; then
        printf '%s\n' "$primary_root/$relative_path"
        return
    fi

    if [ -e "$legacy_root/$relative_path" ]; then
        printf '%s\n' "$legacy_root/$relative_path"
        return
    fi

    printf '%s\n' "$primary_root/$relative_path"
}

vault_is_inside_data_root() {
    local target_path primary_root legacy_root
    target_path=$1
    primary_root=$(vault_primary_data_root)
    legacy_root=$(vault_legacy_data_root)

    case "$target_path" in
        "$primary_root"|"$primary_root"/*|"$legacy_root"|"$legacy_root"/*)
            return 0
            ;;
    esac

    return 1
}

vault_path_for_root() {
    local data_root start_dir project_key project_slug
    data_root=$1
    start_dir=${2:-"$PWD"}

    project_key=$(vault_resolve_project_key "$start_dir")
    project_slug=$(vault_resolve_project_slug "$start_dir")

    if [ -n "$project_key" ] && [ -d "$data_root/by-repo" ]; then
        printf '%s\n' "$data_root/by-repo/$project_key"
        return
    fi

    if [ -n "$project_key" ] && [ "${data_root%/by-repo}" != "$data_root" ]; then
        printf '%s\n' "$data_root/$project_key"
        return
    fi

    printf '%s\n' "$data_root/$project_slug"
}

vault_resolve_project_vault() {
    local base_path
    base_path=$(vault_find_base)
    vault_path_for_root "$base_path" "${1:-"$PWD"}"
}

vault_resolve_existing_project_vault() {
    local start_dir primary_root legacy_root primary_candidate legacy_candidate
    start_dir=${1:-"$PWD"}
    primary_root=$(vault_primary_data_root)
    legacy_root=$(vault_legacy_data_root)

    primary_candidate=$(vault_path_for_root "$primary_root" "$start_dir")
    if [ -d "$primary_candidate" ]; then
        printf '%s\n' "$primary_candidate"
        return
    fi

    primary_candidate=$(vault_path_for_root "$primary_root/by-repo" "$start_dir")
    if [ -d "$primary_candidate" ]; then
        printf '%s\n' "$primary_candidate"
        return
    fi

    legacy_candidate=$(vault_path_for_root "$legacy_root" "$start_dir")
    if [ -d "$legacy_candidate" ]; then
        printf '%s\n' "$legacy_candidate"
        return
    fi

    legacy_candidate=$(vault_path_for_root "$legacy_root/by-repo" "$start_dir")
    if [ -d "$legacy_candidate" ]; then
        printf '%s\n' "$legacy_candidate"
        return
    fi

    vault_resolve_project_vault "$start_dir"
}
