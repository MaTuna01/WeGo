import MapKit
import SwiftData
import SwiftUI

/// 이용 내역 한 줄(Figma 337:1064): 왼쪽 날짜(월, 일), 오른쪽 회색 카드에 정류장, 주행 시간, 추가요금 여부.
/// 디자인의 북마크, 별 배지는 저장 기능(#48)과 함께 넣는다.
struct RideHistoryRow: View {
    let ride: RideRecord

    var body: some View {
        let date = Self.dateParts(ride.startedAt)
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 2) {
                Text(date.month)
                    .wegoFont(.regular, 12)
                    .foregroundStyle(WeGoColor.gray500)
                Text(date.day)
                    .wegoFont(.bold, 18, tracking: -0.4)
                    .foregroundStyle(.black)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(ride.historyTitle)
                    .wegoFont(.medium, 15, tracking: -0.4)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label(WeGoFormat.minutesAndSeconds(ride.ridingSeconds) + " 라이딩", systemImage: "clock")
                        .foregroundStyle(WeGoColor.textBody)
                    Label(ride.hasExtraFee ? "추가요금 발생" : "추가요금 없음", systemImage: "wonsign.circle")
                        .foregroundStyle(ride.hasExtraFee ? WeGoColor.red : WeGoColor.textBody)
                }
                .labelStyle(RideHistoryLabelStyle())
                .wegoFont(.regular, 13, tracking: -0.3)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WeGoColor.gray100, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let date = Self.dateParts(ride.startedAt)
        let fee = ride.hasExtraFee ? "추가요금 발생" : "추가요금 없음"
        return "\(date.month) \(date.day), \(ride.historyTitle), \(WeGoFormat.minutesAndSeconds(ride.ridingSeconds)) 라이딩, \(fee)"
    }

    /// "11월", "14일"
    static func dateParts(_ date: Date, calendar: Calendar = .current) -> (month: String, day: String) {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return ("\(parts.month ?? 0)월", "\(parts.day ?? 0)일")
    }
}

/// 아이콘과 글자 사이를 좁힌 라벨
private struct RideHistoryLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .font(.system(size: 12, weight: .regular))
            configuration.title
        }
    }
}

/// 최근 이용 내역 지도 카드(369x119): 최근 주행을 시작한 곳에 오리 표시. 움직이지 않는 지도다.
struct RideHistoryMapCard: View {
    @Environment(AppState.self) private var appState
    let rides: [RideRecord]

    var body: some View {
        let points = markerCoordinates
        Map(initialPosition: .region(region(for: points)), interactionModes: []) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, coordinate in
                Annotation("", coordinate: coordinate, anchor: .center) {
                    Image("duckSkyHat")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .padding(3)
                        .background(.white, in: Circle())
                        .overlay(Circle().strokeBorder(WeGoColor.primaryLight, lineWidth: 1))
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // 기록이 바뀌면 지도를 다시 맞춘다.
        .id(rides.map(\.id))
        .frame(height: 119)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 출발 정류장 위치(정류장 목록에 없으면 경로 첫 점)
    private var markerCoordinates: [CLLocationCoordinate2D] {
        rides.compactMap { ride in
            let stationID = ride.matchedStartStationID ?? ride.startStationID
            if let station = appState.stationRepository.station(id: stationID) {
                return station.coordinate
            }
            return ride.trackPoints.first?.coordinate
        }
    }

    private func region(for points: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        CourseRouteGeometry.region(fitting: points, padding: 1.8) ?? MockData.defaultRegion
    }
}

/// 이용 내역이 없을 때
struct RideHistoryEmpty: View {
    var body: some View {
        Text("아직 이용 내역이 없어요.\n정류장에서 대여하고 달리면 여기에 기록돼요.")
            .wegoFont(.regular, 14, lineHeight: 22)
            .foregroundStyle(WeGoColor.gray500)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(WeGoColor.gray100, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 전체 이용 내역("이용 내역 >"), 최신순
struct RideHistoryListView: View {
    @Environment(\.tabBarHeight) private var tabBarHeight
    @Query(sort: \RideRecord.endedAt, order: .reverse) private var rides: [RideRecord]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if rides.isEmpty {
                    RideHistoryEmpty()
                } else {
                    ForEach(rides) { ride in
                        RideHistoryRow(ride: ride)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, tabBarHeight + 24)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("이용 내역")
        .navigationBarTitleDisplayMode(.inline)
    }
}
