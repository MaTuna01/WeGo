#!/usr/bin/env bash
# WeGo Figma 에셋(SVG/PNG)과 Pretendard 폰트를 받아 Xcode 프로젝트에 넣는다.
# 사용법 (ios 디렉토리 어디서든):  sh scripts/fetch-figma-assets.sh
#
# - 에셋 출처: Figma "WeGo" 파일(pxBbUpRjKVW2LeJiTJ6iLX)의 와이어프레임·디자인시스템 노드.
# - Figma MCP 에셋 URL은 발급 후 7일(2026-11-18경) 지나면 만료된다.
#   만료로 실패하면 Claude에게 "Figma 에셋 URL 갱신"을 요청해 이 표를 다시 채운다.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="https://www.figma.com/api/mcp/asset"
CATALOG="WeGo/Resources/Assets.xcassets/Figma"
FONT_DIR="WeGo/Resources/Fonts"
PRETENDARD_VERSION="1.3.9"

mkdir -p "$CATALOG" "$FONT_DIR"
cat > "$CATALOG/Contents.json" <<'JSON'
{ "info" : { "author" : "xcode", "version" : 1 } }
JSON

# 이름 | Figma 에셋 ID | 확장자 | 출처 노드
ASSETS="
splashLogoKo|c0c80106-eb72-4be0-b071-d17de8182ad3|svg|143:344 위고 손글씨 로고
splashLine1|dc8758a6-4ab3-40a7-b1b4-179913bc98ce|svg|143:352
splashLine2|d5e747fc-d856-48c0-a08e-0b0b6393f739|svg|143:353
splashLine3|251f062c-db58-478a-8d97-b732eb6647ab|svg|143:354
splashLine4|a0b1f7d5-6ee1-4edc-a881-dda35b4035bd|svg|143:355
splashAccent1|4b4172d6-b947-49fb-bf42-78e06b1b2a08|svg|143:357
splashAccent2|a43dc64d-93fa-49e5-b909-955e81d4b66e|svg|143:358
splashAccent3|01b8ff11-3f2b-4690-98b9-a7e5cfeca65b|svg|143:359
duckRider|991c9b7b-675f-44d1-a189-46cc5e7f62a7|png|143:356 주황 헬멧 오리
duckRiderLogin|3c9fa369-9308-4848-9175-270b98203325|png|143:398 주황 헬멧 오리(로그인)
splashPhoto|1891875d-2da7-428b-8bb7-df6990c8e985|png|143:449 따릉이 사진
splashLogoWego|321d729a-c6ab-4897-a428-7992527774d7|svg|143:451 WEGO 로고
iconGoogle|14f753cd-4f6d-47d9-8769-32286922273e|svg|143:393
iconApple|f60a3d3c-2d54-455f-bd86-190c1ad11c33|svg|143:400
mapButtonBg|87d5867c-5333-4008-ac9b-cac83dccac41|svg|143:466
mapButtonIcon|3366f099-f619-4969-bd3b-d5b7c4aad10e|svg|143:480
locHalo|9c4be6f2-7fb0-4413-99af-6a58a816e3f1|svg|143:482 내 위치
locHeading|284db28e-9e09-49c3-8452-a4edaa73c627|svg|143:483
locRing|f0ee7595-fe8f-4cb4-9181-8028630649e9|svg|143:484
locDot|9cc873af-dcdb-4c34-a78e-8fa70fc1fbf2|svg|143:485
pinStation|70e21fcc-f138-454b-b7ca-494a2db55485|svg|143:487 정류장 핀
pinBikeBadge|9b956d83-b0d5-410a-b28a-cde586304290|svg|143:488
pinStationSelected|0728bb3e-24aa-411b-80d6-91de3650e094|svg|143:500 선택된 정류장 핀
pinSelectedBadge|b4708eab-e441-41e1-a0d2-8ea50937be05|svg|143:502
pinSelectedBike|f62d6a53-d899-492d-9dac-c5d2314e49fa|svg|143:503
tabHomeOn|c5d9d2c5-01fd-495e-b02c-0374c1740ccf|svg|138:474 탭 홈(활성)
tabHomeOff|641fa41b-6ee4-4daa-8171-cc71a0ecfd17|svg|138:504 탭 홈(비활성)
tabSavedOn|3a5535d6-fa55-4367-b11c-a2e07423c2fa|svg|138:472 탭 저장(활성)
tabSavedOff|b81cd11f-2903-4503-9b7a-547527ddaeb1|svg|138:510 탭 저장(비활성)
tabRideOff|f04bc9f1-fcc7-4906-9df4-2b5ae59d0c68|svg|138:496 탭 자전거(비활성)
tabRideOn|7ef5d743-7e24-48eb-8e55-216b45272bb4|svg|143:467 탭 자전거(활성)
tabRideWheel|a2d3d4c9-8633-45c4-8eca-129642a949b5|svg|143:509 탭 자전거 바퀴(활성)
tabProfileOn|c1bb5ffe-b4f9-480b-be20-adf62ae91b43|svg|138:489 탭 내 정보(활성)
tabProfileOff|73712b93-6f26-4e85-8b59-b1c2f66f6977|svg|138:505 탭 내 정보(비활성)
"

ok=0; failed=""
while IFS='|' read -r name id ext note; do
  [ -z "$name" ] && continue
  dir="$CATALOG/$name.imageset"
  mkdir -p "$dir"
  if curl -fsSL "$BASE/$id.$ext" -o "$dir/$name.$ext"; then
    if [ "$ext" = "svg" ]; then
      props=',"properties" : { "preserves-vector-representation" : true }'
    else
      props=''
    fi
    cat > "$dir/Contents.json" <<JSON
{
  "images" : [ { "filename" : "$name.$ext", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }$props
}
JSON
    ok=$((ok + 1)); echo "✓ $name"
  else
    rm -rf "$dir"; failed="$failed $name"; echo "✗ $name ($note)"
  fi
done <<< "$ASSETS"

echo "Pretendard $PRETENDARD_VERSION 내려받는 중..."
tmp="$(mktemp -d)"
if curl -fsSL "https://github.com/orioncactus/pretendard/releases/download/v$PRETENDARD_VERSION/Pretendard-$PRETENDARD_VERSION.zip" -o "$tmp/pretendard.zip"; then
  unzip -q "$tmp/pretendard.zip" -d "$tmp/pretendard"
  for w in Regular Medium SemiBold Bold; do
    f="$(find "$tmp/pretendard" -name "Pretendard-$w.otf" | head -n 1)"
    if [ -n "$f" ]; then cp "$f" "$FONT_DIR/"; echo "✓ Pretendard-$w.otf"; else failed="$failed Pretendard-$w"; fi
  done
  # OFL은 폰트를 재배포할 때 라이선스 전문을 같이 넣도록 요구한다.
  lic="$(find "$tmp/pretendard" -iname "LICENSE*" | head -n 1)"
  if [ -n "$lic" ]; then cp "$lic" "$FONT_DIR/OFL.txt"; echo "✓ OFL.txt"; else echo "! 압축 파일에 라이선스가 없어 기존 OFL.txt를 유지합니다"; fi
else
  failed="$failed Pretendard"
fi
rm -rf "$tmp"

echo ""
echo "에셋 $ok개 완료."
if [ -n "$failed" ]; then
  echo "실패:$failed"
  exit 1
fi
