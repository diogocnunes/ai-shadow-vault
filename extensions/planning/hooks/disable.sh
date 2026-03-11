#!/bin/bash

set -euo pipefail

PROJECT_ROOT="${AI_SHADOW_PROJECT_ROOT:-$PWD}"

rm -f "$PROJECT_ROOT/.ai/agents/user-stories.sh"
