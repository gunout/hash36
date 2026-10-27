#!/usr/bin/env bash
# rebuild.sh — reconstruit le wheel et le teste dans un venv vierge
set -euo pipefail
cd "$(dirname "$0")"

echo "▶ Activation du venv projet..."
source .venv/bin/activate

echo "▶ Nettoyage..."
rm -rf dist build *.egg-info

echo "▶ Build..."
python -m build

echo "▶ Vérification twine..."
twine check dist/*

echo "▶ Test dans venv vierge..."
deactivate
python3 -m venv /tmp/test_rebuild_$$
source /tmp/test_rebuild_$$/bin/activate
pip install --quiet dist/*.whl

echo "▶ Tests de validation..."
hash36 hash -P "test" --json > /tmp/rec_$$.json
grep -q '"status"' /tmp/rec_$$.json && { echo "❌ status présent"; exit 1; } || echo "✅ record pur"
tail -c 1 /tmp/rec_$$.json | xxd | grep -q "0a" && echo "✅ newline final" || { echo "❌ pas de newline"; exit 1; }
hash36 verify -P "test" -r /tmp/rec_$$.json --json

deactivate
rm -rf /tmp/test_rebuild_$$ /tmp/rec_$$.json
echo "✅ Tout est OK"