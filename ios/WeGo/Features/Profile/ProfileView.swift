import SwiftData
import SwiftUI

/// 마이페이지(MY 탭, Figma 337:1064).
/// 1.1은 로그인이 없어 상단은 이름 없는 인사만 두고, 알림, 설정, 메뉴 줄(저장 / 즐겨찾기 / 내 리뷰 / 내 댓글)은 숨긴다.
/// 아래는 기기에 저장된 주행 기록으로 이용 내역을 보여 준다. 공지사항은 웹 페이지가 생기면(1.2) 넣는다.
struct ProfileView: View {
    @Environment(\.tabBarHeight) private var tabBarHeight

    /// 마이페이지에 보여 주는 최근 이용 내역 개수(디자인: 4줄)
    static let recentCount = 4

    @Query(ProfileView.recentRidesDescriptor) private var recentRides: [RideRecord]

    private static var recentRidesDescriptor: FetchDescriptor<RideRecord> {
        var descriptor = FetchDescriptor<RideRecord>(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
        descriptor.fetchLimit = recentCount
        return descriptor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    greeting
                        .padding(.top, 20)

                    history
                        .padding(.top, 32)

                    footer
                        .padding(.top, 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, tabBarHeight + 24)
            }
            .background(Color.white.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// 오리 + 인사. 로그인(1.2)이 생기면 "OO님 안녕하세요!"로 바꾼다.
    private var greeting: some View {
        HStack(spacing: 8) {
            Image("duckSkyHat")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            Text("안녕하세요!")
                .wegoFont(.bold, 20, tracking: -0.5)
                .foregroundStyle(WeGoColor.gray900)
        }
    }

    @ViewBuilder
    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            if recentRides.isEmpty {
                Text("이용 내역")
                    .wegoFont(.bold, 18, tracking: -0.5)
                    .foregroundStyle(.black)
                RideHistoryEmpty()
            } else {
                NavigationLink {
                    RideHistoryListView()
                } label: {
                    HStack(spacing: 6) {
                        Text("이용 내역")
                            .wegoFont(.bold, 18, tracking: -0.5)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("전체 이용 내역을 봐요")

                RideHistoryMapCard(rides: recentRides)
                    .padding(.bottom, 8)

                ForEach(recentRides) { ride in
                    RideHistoryRow(ride: ride)
                }
            }
        }
    }

    /// 아래 링크. 디자인은 공지사항 | 약관 및 정책이지만 공지사항은 1.2에 넣는다.
    private var footer: some View {
        NavigationLink {
            PolicyView()
        } label: {
            Text("약관 및 정책")
                .wegoFont(.regular, 15, tracking: -0.3)
                .foregroundStyle(WeGoColor.textBody)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: RideRecord.self, inMemory: true)
        .environment(AppState())
}
