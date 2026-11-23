-- 운영사에서 받은 정류장. id는 앱에 주는 ID라 한 번 정하면 바꾸지 않음(앱의 주행 기록, 저장 코스가 가리킴)
-- 잔여 대수처럼 자주 바뀌는 값은 저장하지 않음
CREATE TABLE stations (
    id            VARCHAR(64)      PRIMARY KEY,
    -- 운영사 코드(ttareungyi, tashu). API의 operator 값과 같음
    operator      VARCHAR(20)      NOT NULL,
    -- 운영사 원본 ID. 따릉이는 id와 같음
    source_id     VARCHAR(64)      NOT NULL,
    name          VARCHAR(200)     NOT NULL,
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    -- 공간 검색용 좌표. 위도, 경도에서 DB가 계산하므로 앱 코드는 쓰지 않음
    location      GEOGRAPHY(POINT, 4326)
                  GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography) STORED,
    -- 거치대 수. 모르면 NULL
    dock_count    INTEGER,
    -- 처음 받은 시각, 마지막으로 운영사 목록에 있던 시각
    first_seen_at TIMESTAMPTZ      NOT NULL,
    last_seen_at  TIMESTAMPTZ      NOT NULL,
    -- 운영사 목록에서 빠진 시각. 지우지 않고 표시만 하고, 다시 나타나면 NULL로 되돌림
    removed_at    TIMESTAMPTZ,
    -- 이름, 좌표, 거치대 수, 빠짐 여부가 바뀐 시각
    updated_at    TIMESTAMPTZ      NOT NULL,
    CONSTRAINT uk_stations_operator_source_id UNIQUE (operator, source_id)
);

CREATE INDEX idx_stations_location ON stations USING GIST (location);
-- 서버 시작 시 활성 정류장 조회, 운영사별 반영용
CREATE INDEX idx_stations_operator_active ON stations (operator) WHERE removed_at IS NULL;
