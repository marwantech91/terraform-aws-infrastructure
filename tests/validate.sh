#!/usr/bin/env bash
# Terraform module validation tests
# Validates HCL syntax and configuration for all modules

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

MODULES=("vpc" "eks" "rds" "s3")
ENVS=("dev" "production")

PASS=0
FAIL=0

check() {
  local label="$1"
  local dir="$2"

  if [ ! -d "$dir" ]; then
    echo "  SKIP: $label (directory not found)"
    return
  fi

  if terraform -chdir="$dir" validate -no-color 2>/dev/null; then
    echo "  PASS: $label"
    ((PASS++))
  else
    echo "  FAIL: $label"
    ((FAIL++))
  fi
}

echo "=== Terraform Module Validation ==="
echo ""

echo "Initializing modules..."
for mod in "${MODULES[@]}"; do
  dir="$ROOT_DIR/modules/$mod"
  if [ -d "$dir" ]; then
    terraform -chdir="$dir" init -backend=false -no-color >/dev/null 2>&1 || true
  fi
done

echo ""
echo "Validating modules..."
for mod in "${MODULES[@]}"; do
  check "modules/$mod" "$ROOT_DIR/modules/$mod"
done

echo ""
echo "Validating environments..."
for env in "${ENVS[@]}"; do
  dir="$ROOT_DIR/environments/$env"
  if [ -d "$dir" ]; then
    terraform -chdir="$dir" init -backend=false -no-color >/dev/null 2>&1 || true
    check "environments/$env" "$dir"
  fi
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
