#!/usr/bin/env bash
# Use the versioned hooks in scripts/githooks for this clone (all worktrees share it).
# A branch that doesn't have scripts/githooks yet simply has no hook.
cd "$(dirname "$0")/.." && git config core.hooksPath scripts/githooks && echo "hooks: core.hooksPath=scripts/githooks"
