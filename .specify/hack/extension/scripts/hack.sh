#!/usr/bin/env bash
# Shim: Spec Kit rewrites `scripts/...` paths (frontmatter and command bodies) into the
# extension directory, so the commands and native hooks land here. All logic lives in the repository-root scripts/hack.sh.
exec "$(git rev-parse --show-toplevel)/scripts/hack.sh" "$@"
