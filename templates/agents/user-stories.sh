#!/bin/bash

set -euo pipefail

if command -v vault-user-stories >/dev/null 2>&1; then
    exec vault-user-stories "$@"
fi

echo "vault-user-stories command not found. Load AI Shadow Vault shell integration first."
exit 1
