#!/usr/bin/env bash
# Build Flutter web with compile-time --dart-define.
#
# Run from the Flutter package directory (folder containing pubspec.yaml), i.e. .../curatering-web/curatering
# From repo root: ./curatering/tool/build_web.sh
#
# Optional env (CI / Railway):
#   export API_BASE_URL="https://your-api.up.railway.app"
#   export SUPABASE_URL="https://xxx.supabase.co/rest/v1/"
#   export SUPABASE_ANON_KEY="eyJ..."

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

args=(build web --release)
if [[ -n "${API_BASE_URL:-}" ]]; then
  args+=("--dart-define=API_BASE_URL=${API_BASE_URL}")
fi
if [[ -n "${SUPABASE_URL:-}" ]]; then
  args+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
fi
if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
  args+=("--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")
fi

echo "flutter ${args[*]}"
exec flutter "${args[@]}"
