# Bootstrap Contract — shared sentinel and block extractor.
# Source this file; do not execute directly.

# Single source of truth for the Bootstrap Contract sentinel line.
readonly BOOTSTRAP_CONTRACT_SENTINEL='9. BOOTSTRAP_ACK is an audit signal only (not a guarantee of compliance).'

# Extract the Bootstrap Contract block from a CLAUDE.md file.
# Usage: bootstrap_extract_contract_block <claude_file>
bootstrap_extract_contract_block() {
    local claude_file="$1"
    awk '
        /^## Bootstrap Contract \(Mandatory\)$/ { in_block=1; next }
        in_block && /^## / { exit }
        in_block { print }
    ' "$claude_file"
}
