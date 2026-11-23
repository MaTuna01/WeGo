# WeGo 서버

앱이 쓰는 API 두 개만 제공한다. 6시간마다 서울시 공공자전거 API에서 따릉이 정류장을 받아 DB(stations 테이블)에 반영하고, GET /stations는 요청마다 DB의 활성 정류장을 읽어 응답한다(캐시 없음). 서버를 다시 켜도 운영사 API와 상관없이 마지막 목록으로 응답한다. API 모양은 저장소 루트의 docs/api-contract.md를 따른다.

DB는 PostgreSQL(PostGIS)이다. 스키마는 Flyway가 서버 시작 때 바꾼다(src/main/resources/db/migration). 정류장 좌표는 geography 컬럼과 GiST 인덱스로 저장한다. 운영사 목록에서 빠진 정류장은 지우지 않고 removed_at만 표시한다.

| 경로 | 설명 |
|---|---|
| GET /app/config | 최소 지원 앱 버전 |
| GET /stations | 따릉이 정류장 목록(약한 ETag, 304, gzip). DB에 정류장이 아직 없으면 503 |
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
| SEOUL_OPEN_API_KEY | 예 | 없음 | 서울 열린데이터광장 공공자전거 실시간 대여정보 인증키. 없으면 수집하지 않음(DB에 이전 목록이 있으면 GET /stations는 그 목록으로 응답) |
| WEGO_MINIMUM_VERSION | 아니오 | 1.0.0 | 최소 지원 앱 버전. 올리면 이보다 낮은 앱은 업데이트 안내로 막힌다 |
| SERVER_PORT | 아니오 | 8080 | 서버 포트(Docker 배포에서는 8080 고정) |
| POSTGRES_DB | 예 | wego | DB 이름. 배포에서는 db 컨테이너가 처음 시작할 때 이 이름으로 DB를 만든다 |
| POSTGRES_USER | 예 | wego | DB 계정. 배포에서는 db 컨테이너가 처음 시작할 때 만든다 |
| POSTGRES_PASSWORD | 예 | 없음 | DB 비밀번호. 비어 있으면 배포의 db 컨테이너가 시작하지 않는다. 길고 무작위로(openssl rand -base64 24) |
| DB_HOST | 아니오 | localhost | DB 주소(Docker 배포에서는 db 고정) |
| DB_PORT | 아니오 | 5432 | DB 포트(Docker 배포에서는 5432 고정) |

선택 항목은 바꿀 때만 적는다. KEY= 처럼 빈 값으로 두면 기본값 대신 빈 문자열이 들어가서, WEGO_MINIMUM_VERSION은 서버가 시작하지 않는다.

POSTGRES_ 세 값은 db 컨테이너가 처음 시작할 때(볼륨이 비어 있을 때)만 쓴다. 그 뒤에 .env에서 비밀번호를 바꾸면 서버만 새 비밀번호로 접속하려다 실패한다. 바꿀 때는 DB 안에서 먼저 바꾼다(ALTER USER wego PASSWORD '새 비밀번호').

## 로컬 실행

JDK 21과 Docker(Docker Desktop 등)가 필요하다. 테스트는 Testcontainers로 PostGIS 컨테이너를 직접 띄우므로 Docker만 켜 두면 된다.

    ./gradlew compileJava && ./gradlew test    # PR 품질 게이트

bootRun은 DB가 있어야 시작한다. .env에 POSTGRES_PASSWORD를 채우고 로컬 DB를 띄운다(배포와 같은 이미지, 이 PC에서만 접속).

    docker run -d --name wego-db -p 127.0.0.1:5432:5432 --env-file .env -v wego-db:/var/lib/postgresql/data imresamu/postgis:17-3.5
    ./gradlew bootRun

    docker stop wego-db     # 끄기(데이터는 wego-db 볼륨에 남음), 다시 켤 때 docker start wego-db

Spring Boot는 .env를 직접 읽지 않는다. IntelliJ에서는 EnvFile 플러그인을 설치하고, 실행 설정의 EnvFile 탭에서 Enable EnvFile을 켠 뒤 .env를 목록에 추가한다(Finder 창에서 Cmd + Shift + . 로 숨김 파일 표시). 터미널에서는 환경 변수를 직접 넣는다.

    set -a; . ./.env; set +a; ./gradlew bootRun

시작 로그에 "ttareungyi 정류장 N곳 반영"이 나오면 정상이다.

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
        cp .env.example .env    # SEOUL_OPEN_API_KEY, POSTGRES_PASSWORD 채우기

5. 실행한다. 처음에는 이미지 빌드와 인증서 발급으로 몇 분 걸린다.

        cd deploy
        docker compose up -d --build

6. 확인한다.

        curl https://api.wegoride.site/actuator/health
        curl -s -o /dev/null -w "%{http_code}\n" https://api.wegoride.site/stations    # 200이면 정상
        curl -s -o /dev/null -w "%{http_code}\n" https://wegoride.site/privacy         # 200이면 정상

7. DB 백업을 cron에 등록한다(아래 운영의 백업).

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

### DB 도입 전환(1.1 이전 서버 -> 1.2)

DB 없이 돌던 VM은 한 번만 아래를 한다.

1. .env에 DB 값을 추가한다(.env.example의 POSTGRES_ 세 줄). POSTGRES_PASSWORD는 새로 만든다.

        openssl rand -base64 24    # 이 값을 POSTGRES_PASSWORD에

2. 받고 다시 띄운다. db 컨테이너가 먼저 healthy가 된 뒤 api가 시작하고, 시작 로그에 Flyway가 V1을 적용했다고 나온다.

        cd ~/wego && git pull
        cd wegoBackEnd/deploy && docker compose up -d --build
        docker compose logs api | grep -E "Migrating|Successfully applied|정류장"

3. 메모리를 확인한다(아래 운영의 메모리).

### 운영

    docker compose logs -f api      # 서버 로그(앱 버전, 정류장 갱신)
    docker compose logs -f caddy    # 인증서 발급, 접속 로그
    docker compose restart api      # .env를 바꾼 뒤 반영

- 메모리 1GB VM에서는 이미지 빌드(Gradle) 중에 메모리가 부족할 수 있다. 그때는 스왑을 잡거나, 다른 곳에서 빌드한 이미지를 가져와 실행한다.
- 정적 페이지의 연락처, 시행일을 바꾸면 deploy/site의 HTML을 고치고 dev에 머지한 뒤 VM에서 git pull 한다. 처리방침의 내용이 바뀌면 시행일을 새로 적고, 시행 7일 전(중요한 변경은 30일 전)부터 게시한다.
- caddy_data 볼륨에 인증서가 들어 있다. 지우면 다시 발급받는데, Let's Encrypt 발급 횟수 제한이 있으니 자주 지우지 않는다.
- 서울시 API는 HTTP(8088)만 제공하므로 서버에서 서울시로 가는 구간은 암호화되지 않는다. 인증키는 서버 밖으로 나가지 않게 .env에만 둔다.

#### 메모리

VM 2GB + 스왑 기준으로 컨테이너마다 한도를 두었다(docker-compose.yml의 mem_limit). api 1GB(JVM 힙은 그 75%), db 512MB. 평소 사용량은 api 300MB대, db 수십 MB다. 이미지 빌드(--build) 중에는 Gradle이 메모리를 많이 써서 스왑을 쓸 수 있다.

    free -h                    # 스왑 사용량
    docker stats --no-stream   # 컨테이너별 사용량과 한도
    docker inspect --format '{{.State.OOMKilled}}' deploy-api-1    # api가 혼자 재시작됐다면 true인지 확인

평소에도 스왑이 계속 늘면 api 한도를 768m로 낮춘다.

#### DB 백업과 복구

- DB 데이터는 db_data 볼륨에 있다. docker compose down -v 나 docker volume rm 을 하면 모두 사라지므로 하지 않는다(down만 하는 것은 괜찮다).
- 지금은 정류장처럼 다시 받을 수 있는 데이터뿐이지만, 1.3부터 사용자와 주행 기록이 들어가므로 지금부터 백업을 돌린다.

매일 새벽 4시에 백업하고 14일이 지난 파일은 지운다(crontab -e 에 한 줄 추가, 백업 폴더는 mkdir -p ~/wego-backups 로 먼저 만든다).

    0 4 * * * cd ~/wego/wegoBackEnd/deploy && docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > ~/wego-backups/wego-$(date +\%F).dump && find ~/wego-backups -name '*.dump' -mtime +14 -delete

- 백업 파일이 VM 안에만 있으면 VM을 잃을 때 같이 잃는다. 가끔 내 PC로 받아 둔다(scp).
- 백업 파일에는 1.3부터 개인정보가 들어간다. 저장소나 공유 폴더에 올리지 않는다.

복구는 api를 멈추고 덮어쓴 뒤 다시 켠다.

    cd ~/wego/wegoBackEnd/deploy
    docker compose stop api
    docker compose exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' < ~/wego-backups/wego-2026-12-01.dump
    docker compose start api
