#!/bin/bash
# Vercel 部署后 Smoke Test
# 用法：./scripts/smoke-test.sh [URL]
# 默认 URL：https://earth-online-wine.vercel.app

set -e

URL="${1:-https://earth-online-wine.vercel.app}"
echo "Smoke testing: $URL"

# 检查主页返回 200
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$URL")
if [ "$HTTP_CODE" != "200" ]; then
  echo "FAIL: Main page returned HTTP $HTTP_CODE (expected 200)"
  exit 1
fi
echo "OK: Main page HTTP 200"

# 检查 Flutter bootstrap 脚本可达
FLUTTER_JS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$URL/flutter.js")
if [ "$FLUTTER_JS_CODE" != "200" ]; then
  echo "FAIL: flutter.js returned HTTP $FLUTTER_JS_CODE"
  exit 1
fi
echo "OK: flutter.js accessible"

# 检查 main.dart.js 可达
MAIN_JS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$URL/main.dart.js")
if [ "$MAIN_JS_CODE" != "200" ]; then
  echo "WARN: main.dart.js returned HTTP $MAIN_JS_CODE (may use canvaskit)"
fi

echo "Smoke test passed!"
