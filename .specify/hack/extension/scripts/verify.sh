#!/usr/bin/env bash
# Shim: Spec Kit rewrites every `scripts/...` mention in command bodies into the extension
# directory. This one forwards to the repository-root scripts/verify.sh.
exec "$(git rev-parse --show-toplevel)/scripts/verify.sh" "$@"
