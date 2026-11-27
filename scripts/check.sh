#!/usr/bin/env bash
# Lints and renders every chart with each of its values files in ci/, and
# checks the rendered manifests parse. No cluster needed.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
helm=${HELM:-helm}
out="$(mktemp -d)"; trap 'rm -rf "$out"' EXIT
$helm dependency build "$root/charts/nochaos" >/dev/null
for chart in "$root"/charts/*/; do
  name=$(basename "$chart")
  $helm lint "$chart" >/dev/null || { $helm lint "$chart"; exit 1; }
  values=("")
  for f in "$chart"ci/*-values.yaml; do [ -f "$f" ] && values+=("$f"); done
  for v in "${values[@]}"; do
    $helm template ci "$chart" ${v:+-f "$v"} > "$out/$name.yaml"
    python3 -c 'import sys, yaml; [d for d in yaml.safe_load_all(open(sys.argv[1]))]' "$out/$name.yaml"
    echo "ok  $name${v:+ ($(basename "$v"))} $(grep -c '^kind:' "$out/$name.yaml") objects"
  done
done
