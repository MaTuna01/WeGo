import SwiftUI

/// 코스 취소 확인 모달 (Figma 299:457): 어두운 배경 위 흰 카드(360×419), 오리 일러스트, 문구, 네 / 아니요.
/// 배경을 누르면 아니요와 같다(코스 안내를 이어 간다).
struct RideCancelCourseModal: View {
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                // TODO: 디자이너가 내보낸 duckModal(Figma 300:545)로 교체. 같은 "주황 헬멧 오리 자전거" 그림이라 우선 duckRider를 쓴다.
                DuckRiderImage(width: 208, height: 216)
                    .padding(.top, 26)

                Text("코스 이용을 중지하고\n자유롭게 탑승하시겠습니까?")
                    .wegoFont(.semibold, 22, tracking: -0.5, lineHeight: 34)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                HStack(spacing: 7) {
                    modalButton("네", background: WeGoColor.gray500, action: onConfirm)
                    modalButton("아니요", background: WeGoColor.buttonDark, action: onDismiss)
                }
                .padding(.horizontal, 17)
                .padding(.top, 26)
                .padding(.bottom, 27)
            }
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 21)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func modalButton(_ title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .wegoFont(.medium, 22, tracking: -0.5)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RideCancelCourseModal(onConfirm: {}, onDismiss: {})
        .background(Color.gray.opacity(0.3))
}
