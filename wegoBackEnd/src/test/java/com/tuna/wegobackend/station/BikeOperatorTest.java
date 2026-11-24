package com.tuna.wegobackend.station;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class BikeOperatorTest {

    @Test
    @DisplayName("따릉이는 원본 ID를 그대로 앱 ID로 쓴다")
    void ttareungyiKeepsSourceId() {
        assertThat(BikeOperator.TTAREUNGYI.appIdOf("ST-3401")).isEqualTo("ST-3401");
        assertThat(BikeOperator.TTAREUNGYI.sourceIdOf("ST-3401")).isEqualTo("ST-3401");
    }

    @Test
    @DisplayName("타슈는 원본 ID 앞에 TS-를 붙이고, 떼면 원본으로 돌아온다")
    void tashuAddsPrefix() {
        assertThat(BikeOperator.TASHU.appIdOf("ST0003")).isEqualTo("TS-ST0003");
        assertThat(BikeOperator.TASHU.sourceIdOf("TS-ST0003")).isEqualTo("ST0003");
    }

    @Test
    @DisplayName("타슈 접두어가 없는 ID에서 원본을 꺼내려 하면 예외")
    void tashuRejectsUnprefixedId() {
        assertThatThrownBy(() -> BikeOperator.TASHU.sourceIdOf("ST0003"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
