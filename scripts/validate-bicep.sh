#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v az >/dev/null || { echo "Azure CLI (az) is required" >&2; exit 1; }
az bicep version

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

# Compile current source, not the historical JSON artifacts committed for lab evidence.
for file in azuredeploy.bicep backup.bicep modules/*.bicep; do
  stem="$(basename "$file" .bicep)"
  echo "Building $file"
  az bicep build --file "$file" --outfile "$build_dir/$stem.json"
done

# Check parameter-to-template compatibility for both deployment phases.
for file in dev.bicepparam backup.dev.bicepparam; do
  echo "Validating $file"
  az bicep build-params --file "$file" --outfile "$build_dir/$(basename "$file" .bicepparam).parameters.json"
done

python3 scripts/check_bicep_security.py "$build_dir"
python3 -m unittest discover -s tests -p 'test_*.py' -v

echo "Bicep build, parameter validation and offline security checks passed."
