import SwiftUI

/// 정류장 시트의 세로 코스 카드(362×125, Figma 299:121).
/// 위: 코스 이름 + `>`, 아래: 출발 정류장(하늘색 점) ↔ 도착 정류장(주황 점)을 점선으로 잇는다.
/// 선택된 카드는 주황 테두리. `onDetail`이 있으면 오른쪽 `>`가 코스 상세로 가는 버튼이 된다.
struct CourseRow: View {
    let course: Course
    let startName: String
    let endName: String
    var isSelected = false
    var onDetail: (() -> Void)?

    private let dotSize: CGFloat = 30
    /// 점 중심이 카드 좌우 끝에서 떨어진 거리(디자인: 왼쪽 점 x33, 오른쪽 점 x302 → 중심 48 / 317)
    private let dotInset: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(course.title)
                    .wegoFont(.regular, 14, tracking: -0.7)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.horizontal, 44)
                if let onDetail {
                    HStack {
                        Spacer()
                        Button(action: onDetail) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.black)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)
                    }
                    .padding(.trailing, 4)
                }
            }
            .frame(height: 21)
            .padding(.top, 14)

            route
                .padding(.top, 11)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 125)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(WeGoColor.primaryLight, lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(course.title), \(startName)에서 \(endName)까지")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "코스 상세 보기") { onDetail?() }
    }

    /// 점 두 개와 점선, 그 아래 정류장 이름
    private var route: some View {
        GeometryReader { proxy in
            let leftX = dotInset
            let rightX = proxy.size.width - dotInset
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: leftX + dotSize / 2, y: dotSize / 2))
                    path.addLine(to: CGPoint(x: rightX - dotSize / 2, y: dotSize / 2))
                }
                .stroke(WeGoColor.primaryLight.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                stop(color: WeGoColor.sky, name: startName)
                    .position(x: leftX, y: dotSize / 2)
                    .offset(y: stopLabelOffset)
                stop(color: WeGoColor.primaryLight, name: endName)
                    .position(x: rightX, y: dotSize / 2)
                    .offset(y: stopLabelOffset)
            }
        }
        .frame(height: dotSize + 36)
    }

    /// `stop`은 점 아래로 이름이 붙어 있어서, 점 중심이 `position`에 오도록 내린다.
    private var stopLabelOffset: CGFloat { 18 }

    private func stop(color: Color, name: String) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
            Text(name)
                .wegoFont(.regular, 12, tracking: -0.6, lineHeight: 14)
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 88)
                .frame(height: 30, alignment: .top)
        }
    }
}

#Preview {
    let course = MockData.courses[0]
    VStack(spacing: 12) {
        CourseRow(course: course, startName: "여의나루역 1번출구 앞", endName: "여의도 한강공원 원효대교 남단", isSelected: true)
        CourseRow(course: course, startName: "서울숲", endName: "서울 한강공원")
    }
    .padding(20)
    .background(WeGoColor.surface)
}
