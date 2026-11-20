import SwiftUI

/// 데이터 출처 고지. 공공데이터는 출처를 밝혀야 하고, 운영 기관과 관계없는 앱이라는 점도 함께 적는다.
struct DataSourceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NoticeBlock(
                    title: "정류장 정보",
                    text: "서울 열린데이터광장의 \"서울특별시 공공자전거 실시간 대여정보\"를 가공해 사용해요. "
                        + "정류장 이름과 위치는 서버에서 하루 몇 차례 갱신하며, 실제와 다를 수 있어요."
                )
                NoticeBlock(
                    title: "지도",
                    text: "Apple 지도(MapKit)를 사용해요. 지도 데이터의 출처는 지도 화면 아래의 \"법적 고지\"에서 볼 수 있어요."
                )
                NoticeBlock(
                    title: "운영 기관과의 관계",
                    text: "위고는 서울특별시, 대전광역시와 각 공유자전거 운영 기관이 만든 앱이 아니며, 이들과 제휴 관계가 없어요. "
                        + "따릉이, 타슈의 대여와 반납, 요금 결제는 각 운영 기관의 공식 앱에서 해 주세요."
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, ProfileLayout.tabBarReserve)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("데이터 출처")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct NoticeBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .wegoFont(.semibold, 16, tracking: -0.4)
                .foregroundStyle(WeGoColor.gray900)
            Text(text)
                .wegoFont(.regular, 14, lineHeight: 22)
                .foregroundStyle(WeGoColor.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack { DataSourceView() }
}
