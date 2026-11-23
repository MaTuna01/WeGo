import SwiftUI

/// 오픈소스 라이선스 고지. 1.0이 쓰는 외부 자산은 Pretendard 글꼴뿐이다(외부 패키지 없음).
/// SIL OFL은 글꼴과 함께 라이선스 전문을 배포하도록 요구하므로 앱 번들의 OFL.txt를 그대로 보여준다.
struct LicensesView: View {
    @Environment(\.tabBarHeight) private var tabBarHeight
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pretendard")
                    .wegoFont(.semibold, 16, tracking: -0.4)
                    .foregroundStyle(WeGoColor.gray900)
                Text("SIL Open Font License 1.1\nhttps://github.com/orioncactus/pretendard")
                    .wegoFont(.regular, 13, lineHeight: 20)
                    .foregroundStyle(WeGoColor.gray500)
                    .textSelection(.enabled)
                Text(Self.pretendardLicense)
                    .wegoFont(.regular, 12, lineHeight: 18)
                    .foregroundStyle(WeGoColor.textBody)
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WeGoColor.gray100, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, tabBarHeight + 24)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    /// Resources/Fonts/OFL.txt (폴더 동기화 그룹이라 앱 번들 최상위에 들어간다)
    static let pretendardLicense: String = Bundle.main.url(forResource: "OFL", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        .map(reflow) ?? "SIL Open Font License 1.1"

    /// 원문은 70자쯤에서 줄을 끊어 두어 좁은 화면에서는 한 줄이 두 번 꺾인다.
    /// 빈 줄로 나뉜 문단 안의 줄바꿈만 공백으로 바꿔 화면 폭에 맞게 흐르게 한다(내용은 그대로).
    static func reflow(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { paragraph in
                var lines = paragraph.split(separator: "\n", omittingEmptySubsequences: true)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.allSatisfy { $0 == "-" } }
                // "PREAMBLE"처럼 대문자로만 된 첫 줄은 제목이라 따로 둔다.
                guard let first = lines.first else { return "" }
                if lines.count > 1, first == first.uppercased(), first.contains(where: \.isLetter) {
                    lines.removeFirst()
                    return first + "\n" + lines.joined(separator: " ")
                }
                return lines.joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

#Preview {
    NavigationStack { LicensesView() }
}
