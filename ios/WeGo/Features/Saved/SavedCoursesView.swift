import MapKit
import SwiftData
import SwiftUI

/// 저장 탭(Figma 369:1692): 지도 위 시트에 저장, 즐겨찾기한 코스 목록.
/// 위: 정렬(최신순 / 이름순)과 칩(전체 / 저장한 코스 / 즐겨찾기한 코스). 줄을 누르면 지도에 그 코스 경로를 보여 준다.
/// 줄 오른쪽 더보기에서 홈 정류장 시트로 코스 보기, 저장이나 즐겨찾기 해제.
struct SavedCoursesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tabBarHeight) private var tabBarHeight

    @Query(sort: \SavedCourse.markedAt, order: .reverse) private var savedCourses: [SavedCourse]

    @State private var filter: SavedCourseFilter = .all
    @State private var sort: SavedCourseSort = .recent
    @State private var selectedCourseID: String?
    @State private var detent: SheetDetent = .standard
    @State private var camera: MapCameraPosition = .region(MockData.defaultRegion)
    @State private var containerHeight: CGFloat = 0

    private var shownCourses: [SavedCourse] {
        SavedCourseFilter.apply(filter, sort: sort, to: savedCourses)
    }

    private var selectedCourse: Course? {
        shownCourses.first { $0.courseID == selectedCourseID }?.course
    }

    var body: some View {
        ZStack {
            SavedCourseMap(course: selectedCourse, camera: $camera)
                .ignoresSafeArea()
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
        .overlay(alignment: .bottom) {
            DraggableBottomSheet(detent: $detent, heights: sheetHeights) {
                VStack(alignment: .leading, spacing: 0) {
                    controls
                        .padding(.top, 18)
                        .padding(.horizontal, 20)
                    list
                        .padding(.top, 20)
                }
            }
        }
        .onAppear { selectFirstIfNeeded() }
        .onChange(of: shownCourses.map(\.courseID)) { _, _ in selectFirstIfNeeded() }
        .onChange(of: selectedCourseID) { _, _ in fitSelectedCourse() }
        .onChange(of: detent) { _, _ in fitSelectedCourse() }
    }

    // MARK: 정렬과 칩

    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("정렬", selection: $sort) {
                    ForEach(SavedCourseSort.allCases, id: \.self) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sort.title)
                        .wegoFont(.regular, 14, tracking: -0.7)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 7))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(WeGoColor.chip, in: Capsule())
            }
            .accessibilityLabel("정렬, \(sort.title)")

            ForEach(SavedCourseFilter.allCases, id: \.self) { item in
                Button {
                    filter = item
                } label: {
                    Text(item.title)
                        .wegoFont(filter == item ? .semibold : .regular, 14, tracking: -0.7)
                        .foregroundStyle(filter == item ? .white : .black)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(filter == item ? WeGoColor.gray900 : WeGoColor.chip, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == item ? .isSelected : [])
            }
        }
    }

    // MARK: 목록

    @ViewBuilder
    private var list: some View {
        if shownCourses.isEmpty {
            Text(filter.emptyMessage)
                .wegoFont(.regular, 14, lineHeight: 22)
                .foregroundStyle(WeGoColor.gray500)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 40)
                .padding(.horizontal, 20)
                .fadesWhenSheetCollapses()
        } else {
            SheetScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(shownCourses) { saved in
                        SavedCourseRow(
                            saved: saved,
                            filter: filter,
                            isSelected: saved.courseID == selectedCourseID,
                            onSelect: { selectedCourseID = saved.courseID },
                            onShowOnHome: { appState.showOnHome(saved.course) },
                            onRemove: { mark in remove(mark, from: saved) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, tabBarHeight + 24)
            }
            .fadesWhenSheetCollapses()
        }
    }

    private func remove(_ mark: CourseMark, from saved: SavedCourse) {
        SavedCourse.toggle(
            mark,
            for: saved.course,
            startStationName: saved.startStationName,
            endStationName: saved.endStationName,
            in: modelContext
        )
    }

    // MARK: 시트와 지도

    private func sheetHeights(_ height: CGFloat) -> SheetHeights {
        SheetHeights(
            collapsed: tabBarHeight + 24,
            standard: height * 0.6,
            expanded: height - 70
        )
    }

    private func selectFirstIfNeeded() {
        if !shownCourses.contains(where: { $0.courseID == selectedCourseID }) {
            selectedCourseID = shownCourses.first?.courseID
        }
    }

    /// 선택한 코스가 시트 위에 보이는 지도 영역에 들어오도록 카메라를 옮긴다.
    private func fitSelectedCourse() {
        guard let selectedCourse, containerHeight > 0 else { return }
        let sheetTop = containerHeight - sheetHeights(containerHeight).height(for: detent)
        let top = 60 / containerHeight
        let bottom = (sheetTop - 12) / containerHeight
        guard bottom - top > 0.08,
              let region = StationMapView.region(fitting: selectedCourse, visibleTop: top, visibleBottom: bottom)
        else { return }
        withAnimation { camera = .region(region) }
    }
}

/// 저장 탭 배경 지도: 선택한 코스의 경로와 출발(하늘색), 도착(빨강) 점
private struct SavedCourseMap: View {
    let course: Course?
    @Binding var camera: MapCameraPosition

    var body: some View {
        Map(position: $camera) {
            if let course, course.path.count > 1, let first = course.coordinates.first, let last = course.coordinates.last {
                MapPolyline(coordinates: course.coordinates)
                    .stroke(WeGoColor.primaryLight, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                Annotation("", coordinate: first) { dot(WeGoColor.sky) }
                Annotation("", coordinate: last) { dot(WeGoColor.red) }
            }
            UserAnnotation {
                CurrentLocationMarker()
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
    }
}

/// 목록 한 줄: 원형 아이콘(북마크 또는 별) + 회색 칸(코스 이름, 거리, 예상 시간, 출발 정류장) + 더보기
private struct SavedCourseRow: View {
    let saved: SavedCourse
    let filter: SavedCourseFilter
    let isSelected: Bool
    let onSelect: () -> Void
    let onShowOnHome: () -> Void
    let onRemove: (CourseMark) -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(WeGoColor.chip, in: Circle())
                .accessibilityHidden(true)

            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(saved.title)
                        .wegoFont(.medium, 14, tracking: -0.4)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(subtitle)
                        .wegoFont(.regular, 12, tracking: -0.3)
                        .foregroundStyle(WeGoColor.textBody)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                menu
            }
            .padding(.leading, 14)
            .frame(minHeight: 52)
            .background(WeGoColor.tabBar, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(WeGoColor.primaryLight, lineWidth: 1)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "코스 보기", onShowOnHome)
    }

    /// 칩이 즐겨찾기면 별, 저장이면 북마크. 전체에서는 즐겨찾기한 코스를 별로 보여 준다.
    private var iconName: String {
        switch filter {
        case .saved: "bookmark"
        case .favorite: "star"
        case .all: saved.isFavorite ? "star" : "bookmark"
        }
    }

    /// 거리와 예상 시간을 앞에 두어, 정류장 이름이 길어 잘려도 숫자는 보이게 한다.
    private var subtitle: String {
        "\(WeGoFormat.distance(saved.distanceMeters)), \(WeGoFormat.approxMinutes(saved.durationSeconds)), \(saved.startStationName) 출발"
    }

    private var menu: some View {
        Menu {
            Button("코스 보기", systemImage: "map", action: onShowOnHome)
            if saved.isSaved {
                Button("저장 해제", systemImage: "bookmark.slash", role: .destructive) { onRemove(.saved) }
            }
            if saved.isFavorite {
                Button("즐겨찾기 해제", systemImage: "star.slash", role: .destructive) { onRemove(.favorite) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("더보기")
    }
}

/// 저장 탭 칩
enum SavedCourseFilter: CaseIterable {
    case all
    case saved
    case favorite

    var title: String {
        switch self {
        case .all: "전체"
        case .saved: "저장한 코스"
        case .favorite: "즐겨찾기한 코스"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: "아직 저장한 코스가 없어요.\n정류장 시트의 코스 카드에서 북마크나 별을 눌러 보세요."
        case .saved: "저장한 코스가 없어요.\n코스 카드의 북마크를 누르면 여기에 모여요."
        case .favorite: "즐겨찾기한 코스가 없어요.\n코스 카드의 별을 누르면 여기에 모여요."
        }
    }

    /// 칩으로 거르고 정렬한다. 최신순은 마지막으로 표시한 시각, 이름순은 코스 이름 가나다순.
    static func apply(_ filter: SavedCourseFilter, sort: SavedCourseSort, to courses: [SavedCourse]) -> [SavedCourse] {
        let filtered = courses.filter { course in
            switch filter {
            case .all: course.isSaved || course.isFavorite
            case .saved: course.isSaved
            case .favorite: course.isFavorite
            }
        }
        switch sort {
        case .recent:
            return filtered.sorted { $0.markedAt > $1.markedAt }
        case .name:
            return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }
}

/// 저장 탭 정렬
enum SavedCourseSort: CaseIterable {
    case recent
    case name

    var title: String {
        switch self {
        case .recent: "최신순"
        case .name: "이름순"
        }
    }
}
