#!/usr/bin/env bash
set -eu

source "$(dirname "$0")/../scripts/git-branch.sh"

[[ "$(strip_git_branch_info 'pose visualization   feature/foo')" == 'pose visualization' ]]
[[ "$(strip_git_branch_info 'release notes   v1.0.0')" == 'release notes' ]]
[[ "$(strip_git_branch_info 'notes  archived')" == 'notes  archived' ]]
