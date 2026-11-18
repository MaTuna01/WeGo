import Charts
import SwiftUI

/// 코스 상세의 경사도 그래프(Figma 299:224 "경사도" 카드 윗부분).
/// 가로축은 출발점부터의 거리, 세로축은 고도. 그래프 아래 양 끝에 출발(하늘색)·도착(주황) 점,
/// 경유 지점은 선 위에 작은 점으로 표시한다. 축 눈금은 디자인에 없어 숨긴다.
struct ElevationChart: View {
    let course: Course

    private let progress: CourseProgress
    private let samples: [ElevationSample]

    /// 끝 점 중심이 카드 좌우에서 떨어진 거리. CourseRow와 같은 값이라 위 카드의 점과 세로로 맞는다.
    private let endInset: CGFloat = 48
    private let endDotSize: CGFloat = 30

    init(course: Course) {
        self.course = course
        progress = CourseProgress(course: course)
        samples = progress.elevationProfile
    }

    var body: some View {
        if samples.count < 2 {
            Text("이 코스는 고도 정보가 없어요.")
                .wegoFont(.regular, 13)
                .foregroundStyle(WeGoColor.gray500)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
        } else {
            VStack(spacing: 4) {
                chart
                    .frame(height: 88)
                    .padding(.horizontal, endInset)
                HStack {
                    endDot(WeGoColor.sky)
                    Spacer()
                    endDot(WeGoColor.primaryLight)
                }
                .padding(.horizontal, endInset - endDotSize / 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(samples, id: \.self) { sample in
                AreaMark(
                    x: .value("거리", sample.distanceMeters),
                    yStart: .value("기준", elevationDomain.lowerBound),
                    yEnd: .value("고도", sample.elevationMeters)
                )
                .foregroundStyle(WeGoColor.primaryLight.opacity(0.15))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("거리", sample.distanceMeters),
                    y: .value("고도", sample.elevationMeters)
                )
                .foregroundStyle(WeGoColor.primaryLight)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            ForEach(waypoints, id: \.name) { waypoint in
                PointMark(
                    x: .value("거리", waypoint.distance),
                    y: .value("고도", waypoint.elevation)
                )
                .symbol {
                    Circle()
                        .fill(.white)
                        .overlay(Circle().strokeBorder(WeGoColor.primaryLight, lineWidth: 3))
                        .frame(width: 15, height: 15)
                }
            }
        }
        .chartXScale(domain: 0...progress.totalMeters)
        .chartYScale(domain: elevationDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func endDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: endDotSize, height: endDotSize)
    }

    /// 고도 차이가 몇 m뿐이어도 선이 납작해지지 않게 위아래로 여유를 둔다.
    private var elevationDomain: ClosedRange<Double> {
        let values = samples.map(\.elevationMeters)
        let low = values.min() ?? 0, high = values.max() ?? 0
        let margin = max((high - low) * 0.3, 3)
        return (low - margin)...(high + margin)
    }

    private var waypoints: [(name: String, distance: Double, elevation: Double)] {
        course.waypoints.compactMap { waypoint in
            guard course.path.indices.contains(waypoint.pathIndex),
                  let elevation = course.path[waypoint.pathIndex].elevationMeters else { return nil }
            return (waypoint.name, progress.distance(toPathIndex: waypoint.pathIndex), elevation)
        }
    }

    private var accessibilitySummary: String {
        let values = samples.map(\.elevationMeters)
        let low = Int((values.min() ?? 0).rounded()), high = Int((values.max() ?? 0).rounded())
        return "경사도 그래프. 고도 \(low)m에서 \(high)m 사이"
    }
}

#Preview {
    ElevationChart(course: MockData.courses[1])
        .padding(.vertical, 24)
        .frame(width: 362)
        .background(.white)
}
