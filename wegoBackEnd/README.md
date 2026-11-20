# WeGo 서버 (1.0 최소 서버)

앱이 쓰는 API 두 개만 제공한다. DB 없이 메모리에 따릉이 정류장 목록을 두고, 6시간마다 서울시 공공자전거 API에서 갱신한다. API 모양은 저장소 루트의 docs/api-contract.md를 따른다.

| 경로 | 설명 |
|---|---|
| GET /app/config | 최소 지원 앱 버전 |
| GET /stations | 따릉이 정류장 목록(약한 ETag, 304, gzip). 아직 못 받았으면 503 |
| GET /actuator/health | 헬스 체크 |

나머지 경로는 모두 403이다. 요청마다 X-App-Version을 로그에 남긴다.

같은 VM의 Caddy가 wegoride.site에서 정적 페이지도 서빙한다(Spring을 거치지 않음). 파일은 deploy/site/에 있다.

| 주소 | 설명 |
|---|---|
| https://wegoride.site/ | 소개 |
| https://wegoride.site/privacy | 개인정보 처리방침(App Store Connect, 앱 내 정보 화면이 여는 주소) |
| https://wegoride.site/support | 지원, 문의(App Store Connect 지원 URL) |

## 환경 변수

.env.example을 .env로 복사해서 채운다. .env는 gitignore 대상이라 커밋되지 않는다.

| 이름 | 필수 | 기본값 | 설명 |
|---|---|---|---|
| SEOUL_OPEN_API_KEY | 예 | 없음 | 서울 열린데이터광장 공공자전거 실시간 대여정보 인증키. 없으면 수집하지 않고 GET /stations가 503 |
| WEGO_MINIMUM_VERSION | 아니오 | 1.0.0 | 최소 지원 앱 버전. 올리면 이보다 낮은 앱은 업데이트 안내로 막힌다 |
| SERVER_PORT | 아니오 | 8080 | 서버 포트(Docker 배포에서는 8080 고정) |

선택 항목은 바꿀 때만 적는다. KEY= 처럼 빈 값으로 두면 기본값 대신 빈 문자열이 들어가서, WEGO_MINIMUM_VERSION은 서버가 시작하지 않는다.

## 로컬 실행

JDK 21이 필요하다.

    ./gradlew compileJava && ./gradlew test    # PR 품질 게이트
    ./gradlew bootRun

Spring Boot는 .env를 직접 읽지 않는다. IntelliJ에서는 EnvFile 플러그인을 설치하고, 실행 설정의 EnvFile 탭에서 Enable EnvFile을 켠 뒤 .env를 목록에 추가한다(Finder 창에서 Cmd + Shift + . 로 숨김 파일 표시). 터미널에서는 환경 변수를 직접 넣는다.

    set -a; . ./.env; set +a; ./gradlew bootRun

시작 로그에 "정류장 N곳 갱신"이 나오면 정상이다.

## 배포 (VM 한 대, Docker)

클라우드 전용 서비스를 쓰지 않으므로 가비아 클라우드와 AWS EC2에서 절차가 같다. 서버를 옮길 때는 새 VM에서 아래를 반복하고 DNS만 바꾼다.

구성: Caddy(80, 443, HTTPS 인증서 자동 발급) -> api(8080, 외부에 열지 않음), Caddy -> deploy/site(정적 페이지)

- 배포 브랜치는 dev다. 백엔드 작업은 backend 브랜치에 모았다가 dev로 머지한 뒤 VM에 반영한다.
- VM에는 서버 폴더(wegoBackEnd)만 받는다(sparse checkout). 앱 코드와 문서는 VM에 두지 않는다.
- Caddy 로그(접속, 오류)에서 IP와 요청 헤더를 지운다. 개인정보 처리방침에 "IP를 저장하지 않음"이라고 적었으므로 Caddyfile의 로그 필터를 지우지 않는다.

### 처음 한 번

1. VM에 Docker와 Docker Compose 플러그인을 설치한다.
2. 방화벽(보안 그룹)에서 인바운드 80, 443(TCP), 443(UDP)을 열고, 22(SSH)는 내 IP만 허용한다. 8080은 열지 않는다.
3. DNS에서 wegoride.site, api.wegoride.site, www.wegoride.site의 A 레코드를 VM 공인 IP로 설정한다. Caddy가 인증서를 받으려면 먼저 되어 있어야 한다.
4. 저장소에서 wegoBackEnd 폴더만 받고 .env를 만든다(git 2.25 이상).

        git clone --filter=blob:none --sparse -b dev https://github.com/MaTuna01/WeGo.git wego
        cd wego
        git sparse-checkout set wegoBackEnd
        cd wegoBackEnd
        cp .env.example .env    # SEOUL_OPEN_API_KEY 채우기

5. 실행한다. 처음에는 이미지 빌드와 인증서 발급으로 몇 분 걸린다.

        cd deploy
        docker compose up -d --build

6. 확인한다.

        curl https://api.wegoride.site/actuator/health
        curl -s -o /dev/null -w "%{http_code}\n" https://api.wegoride.site/stations    # 200이면 정상
        curl -s -o /dev/null -w "%{http_code}\n" https://wegoride.site/privacy         # 200이면 정상

### 업데이트

    cd wego && git pull
    cd wegoBackEnd/deploy && docker compose up -d --build

- 정적 페이지(deploy/site)만 바뀌었으면 git pull만 해도 바로 반영된다(폴더를 Caddy에 그대로 연결함).
- Caddyfile을 바꿨으면 새 설정을 먼저 검사한 뒤 caddy를 다시 시작한다. Caddyfile은 파일 하나만 연결해 두어서, git pull이 파일을 새로 쓰면 실행 중인 컨테이너는 예전 파일을 계속 본다(그래서 reload가 아니라 restart).

        docker compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile    # Valid configuration 확인
        docker compose restart caddy

### 기존 VM 전환(backend 전체 clone -> dev, wegoBackEnd만)

처음에 backend 브랜치를 전체로 받은 VM은 한 번만 아래를 실행한다. .env는 gitignore 대상이라 그대로 남는다.

    cd wego
    git fetch origin
    git sparse-checkout set wegoBackEnd    # 앱 코드, 문서 폴더가 작업 트리에서 사라짐
    git switch -c dev --track origin/dev   # 이미 dev가 있으면 git switch dev && git pull
    cd wegoBackEnd/deploy && docker compose up -d --build    # site 폴더 연결이 추가돼 caddy 컨테이너가 새로 만들어짐

### 운영

    docker compose logs -f api      # 서버 로그(앱 버전, 정류장 갱신)
    docker compose logs -f caddy    # 인증서 발급, 접속 로그
    docker compose restart api      # .env를 바꾼 뒤 반영

- 메모리 1GB VM에서는 이미지 빌드(Gradle) 중에 메모리가 부족할 수 있다. 그때는 스왑을 잡거나, 다른 곳에서 빌드한 이미지를 가져와 실행한다.
- 정적 페이지의 연락처, 시행일을 바꾸면 deploy/site의 HTML을 고치고 dev에 머지한 뒤 VM에서 git pull 한다. 처리방침의 내용이 바뀌면 시행일을 새로 적고, 시행 7일 전(중요한 변경은 30일 전)부터 게시한다.
- caddy_data 볼륨에 인증서가 들어 있다. 지우면 다시 발급받는데, Let's Encrypt 발급 횟수 제한이 있으니 자주 지우지 않는다.
- 서울시 API는 HTTP(8088)만 제공하므로 서버에서 서울시로 가는 구간은 암호화되지 않는다. 인증키는 서버 밖으로 나가지 않게 .env에만 둔다.
