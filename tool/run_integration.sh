#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
backend_dir="${BACKEND_DIR:-$app_dir/../backend-nhac}"
flutter_bin="${FLUTTER_BIN:-flutter}"
run_dir="$(mktemp -d)"
logs_dir="$app_dir/integration-logs"
mkdir -p "$logs_dir"
backend_pid=''
cleanup() {
  if [[ -n "$backend_pid" ]]; then
    kill "$backend_pid" 2>/dev/null || true
    wait "$backend_pid" 2>/dev/null || true
  fi
  rm -rf "$run_dir"
}
trap cleanup EXIT

if [[ ! -f "$backend_dir/pom.xml" ]]; then
  echo 'BACKEND_DIR deve apontar para um checkout de backend-nhac.' >&2
  exit 1
fi
if curl --silent --max-time 1 http://127.0.0.1:18080/actuator/health >/dev/null; then
  echo 'A porta 18080 já está ocupada; pare o processo antes de rodar.' >&2
  exit 1
fi
git -C "$backend_dir" rev-parse HEAD > "$logs_dir/backend-sha.txt"
git -C "$backend_dir" status --porcelain > "$logs_dir/backend-working-tree.txt"
(cd "$backend_dir" && ./mvnw -B -q -DskipTests test-compile dependency:build-classpath \
  "-Dmdep.outputFile=$run_dir/classpath") > "$logs_dir/backend-build.log" 2>&1
classpath="$backend_dir/target/classes:$(cat "$run_dir/classpath")"
javac -cp "$classpath" -d "$run_dir/classes" \
  "$app_dir/tool/integration/backend/MotoboyIntegrationFixture.java"
java -Dspring.devtools.restart.enabled=false -cp "$run_dir/classes:$classpath" br.com.nhac.backend_nhac.BackendNhacApplication \
  --spring.profiles.active=motoboy-integration \
  "--spring.config.additional-location=file:$app_dir/tool/integration/backend/" \
  > "$logs_dir/backend.log" 2>&1 &
backend_pid=$!

for ((attempt=0; attempt<120; attempt++)); do
  if ! kill -0 "$backend_pid" 2>/dev/null; then
    tail -80 "$logs_dir/backend.log"
    exit 1
  fi
  if grep -q MOTOBOY_INTEGRATION_FIXTURE_READY "$logs_dir/backend.log" && \
    curl --fail --silent --max-time 1 http://127.0.0.1:18080/actuator/health >/dev/null; then
    break
  fi
  sleep 1
done
if ! grep -q MOTOBOY_INTEGRATION_FIXTURE_READY "$logs_dir/backend.log"; then
  tail -80 "$logs_dir/backend.log"
  exit 1
fi
cd "$app_dir"
CI=true "$flutter_bin" --suppress-analytics --no-version-check test \
  test/integration/motoboy_backend_test.dart \
  --dart-define=RUN_INTEGRATION=true \
  --dart-define=API_BASE_URL=http://127.0.0.1:18080 \
  --reporter=expanded 2>&1 | tee "$logs_dir/flutter.log"
