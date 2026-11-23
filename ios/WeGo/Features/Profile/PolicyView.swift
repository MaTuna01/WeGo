import SwiftUI

/// 약관 및 정책(마이페이지 아래 링크). 1.0 내 정보 화면에 있던 앱 정보, 지원, 고지 항목을 옮겼다.
struct PolicyView: View {
    @Environment(\.tabBarHeight) private var tabBarHeight

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ProfileSection(title: "정책") {
                    ProfileLinkRow(title: "개인정보 처리방침", url: AppLinks.privacyPolicy)
                    ProfileDivider()
                    NavigationLink {
                        DataSourceView()
                    } label: {
                        ProfileRow(title: "데이터 출처") { ProfileChevron() }
                    }
                    ProfileDivider()
                    NavigationLink {
                        LicensesView()
                    } label: {
                        ProfileRow(title: "오픈소스 라이선스") { ProfileChevron() }
                    }
                }
                .buttonStyle(.plain)

                ProfileSection(title: "지원") {
                    ProfileLinkRow(title: "문의하기", url: AppLinks.support)
                }

                ProfileSection(title: "앱 정보") {
                    ProfileRow(title: "버전") {
                        Text(ProfileView.appVersion)
                            .wegoFont(.regular, 15)
                            .foregroundStyle(WeGoColor.gray500)
                    }
                }

                Text("주행 기록은 이 기기에만 저장되고 서버로 보내지 않아요.")
                    .wegoFont(.regular, 13, lineHeight: 20)
                    .foregroundStyle(WeGoColor.gray500)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, tabBarHeight + 24)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("약관 및 정책")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ProfileView {
    /// Info.plist의 마케팅 버전(예: 1.0.0)
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
}

struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .wegoFont(.medium, 13)
                .foregroundStyle(WeGoColor.gray500)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content
            }
            .background(WeGoColor.gray100, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct ProfileRow<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .wegoFont(.medium, 16, tracking: -0.4)
                .foregroundStyle(WeGoColor.gray900)
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// 사파리로 여는 줄. 앱 밖으로 나간다는 걸 화살표 모양으로 구분한다.
struct ProfileLinkRow: View {
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            ProfileRow(title: title) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WeGoColor.gray500)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Safari에서 열어요")
    }
}

struct ProfileChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(WeGoColor.gray500)
    }
}

struct ProfileDivider: View {
    var body: some View {
        Rectangle()
            .fill(WeGoColor.gray300.opacity(0.6))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }
}

#Preview {
    NavigationStack { PolicyView() }
}
