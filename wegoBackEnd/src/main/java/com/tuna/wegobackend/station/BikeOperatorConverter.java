package com.tuna.wegobackend.station;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

/**
 * DB에는 enum 이름(TTAREUNGYI) 대신 API와 같은 코드(ttareungyi)로 저장
 * - enum 이름을 바꿔도 저장된 값이 깨지지 않음
 */
@Converter(autoApply = true)
public class BikeOperatorConverter implements AttributeConverter<BikeOperator, String> {

    @Override
    public String convertToDatabaseColumn(BikeOperator operator) {
        return operator == null ? null : operator.code();
    }

    @Override
    public BikeOperator convertToEntityAttribute(String code) {
        return code == null ? null : BikeOperator.fromCode(code);
    }
}
