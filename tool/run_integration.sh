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
if [[ "${RUN_DEVICE:-false}" == "true" ]]; then
  device="${DEVICE_ID:-emulator-5554}"
  adb -s "$device" reverse tcp:18080 tcp:18080
  adb -s "$device" emu geo fix -46.633308 -23.550520
  "$flutter_bin" build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:18080
  adb -s "$device" install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s "$device" shell pm grant com.example.nhac_motoboy android.permission.ACCESS_FINE_LOCATION
  adb -s "$device" shell pm grant com.example.nhac_motoboy android.permission.ACCESS_COARSE_LOCATION
  if ! "$flutter_bin" test integration_test/motoboy_device_test.dart -d "$device" --dart-define=API_BASE_URL=http://127.0.0.1:18080 2>&1 | tee "$logs_dir/device.log"; then
    adb -s "$device" exec-out screencap -p > "$logs_dir/device-failure.png" || true
    python3 - "$logs_dir" <<'PY'
import base64, pathlib, re, sys
directory = pathlib.Path(sys.argv[1])
parts = re.findall(r'DEVICE_SCREENSHOT_PART:(\d+):([A-Za-z0-9+/=]+)', (directory / 'device.log').read_text())
if parts:
    ordered = dict(parts)
    encoded = ''.join(ordered[str(i)] for i in range(len(ordered)))
    (directory / 'device-failure.png').write_bytes(base64.b64decode(encoded))
PY
    exit 1
  fi
else
CI=true "$flutter_bin" --suppress-analytics --no-version-check test \
  test/integration/motoboy_backend_test.dart \
  --dart-define=RUN_INTEGRATION=true \
  --dart-define=API_BASE_URL=http://127.0.0.1:18080 \
  --reporter=expanded 2>&1 | tee "$logs_dir/flutter.log"

fi
