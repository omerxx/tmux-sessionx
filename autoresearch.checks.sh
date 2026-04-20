#!/usr/bin/env bash
set -euo pipefail

./tests/profile-sessionx.sh existing >/dev/null
./tests/profile-sessionx.sh new >/dev/null
./tests/profile-sessionx.sh directory >/dev/null
./tests/profile-sessionx.sh window >/dev/null
./tests/benchmark-popup-render.sh 3 >/dev/null
