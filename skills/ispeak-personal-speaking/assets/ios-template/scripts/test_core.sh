#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build="$(mktemp -d "${TMPDIR:-/tmp}/ispeak-core.XXXXXX")"
trap 'rm -rf "$task_build"' EXIT
swiftc -parse-as-library "$task_root/App/Core/Curriculum.swift" "$task_root/App/Core/LearningStore.swift" "$task_root/Tests/CoreTests.swift" -o "$task_build/core-tests"
if [[ -f "$task_root/App/Resources/curriculum.json" ]]; then
  "$task_build/core-tests" "$task_root/App/Resources/curriculum.json"
else
  "$task_build/core-tests"
fi
