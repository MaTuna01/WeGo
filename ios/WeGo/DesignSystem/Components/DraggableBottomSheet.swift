import SwiftUI

/// 바텀시트가 멈추는 높이 단계
enum SheetDetent: Int, CaseIterable, Comparable {
    /// 손잡이만 간신히 보임
    case collapsed
    /// Figma 기본 높이
    case standard
    /// 위 검색바·칩 바로 아래까지
    case expanded

    static func < (lhs: SheetDetent, rhs: SheetDetent) -> Bool { lhs.rawValue < rhs.rawValue }

    var next: SheetDetent? { SheetDetent(rawValue: rawValue + 1) }
    var previous: SheetDetent? { SheetDetent(rawValue: rawValue - 1) }

    var accessibilityName: String {
        switch self {
        case .collapsed: "접힘"
        case .standard: "기본"
        case .expanded: "펼침"
        }
    }
}

/// 단계별 시트 높이(시트를 담은 영역 아래끝에서 시트 윗변까지, pt)
struct SheetHeights {
    var collapsed: CGFloat
    var standard: CGFloat
    var expanded: CGFloat

    func height(for detent: SheetDetent) -> CGFloat {
        switch detent {
        case .collapsed: collapsed
        case .standard: standard
        case .expanded: expanded
        }
    }
}

/// 손잡이를 끌어 올리고 내리는 바텀시트(Draggable bottom sheet).
/// 놓으면 손을 뗀 속도까지 감안한 위치에서 가장 가까운 단계로 붙는다.
///
/// 시스템 `.sheet`는 플로팅 탭바 위에 떠서 탭바를 가리므로 직접 그린다.
/// 화면 전체 크기로 두고 아래에 붙여 쓴다. 시트 밖 빈 영역은 터치를 막지 않아 지도를 그대로 움직일 수 있다.
///
/// 시트 안 스크롤은 `SheetScrollView`로 감싼다. 펼침에서만 스크롤되고, 그 외 단계에서는 끌면 시트가 움직인다.
/// 펼침에서 목록이 맨 위일 때 아래로 끌면 시트가 내려간다.
struct DraggableBottomSheet<Content: View>: View {
    @Binding var detent: SheetDetent
    var handleTopPadding: CGFloat = 10
    /// 접힘에 가까워질수록 내용을 흐리게 해 손잡이만 남긴다. 접힘에서도 보여야 하는 버튼이 있으면 끄고 직접 처리한다.
    var fadesContentWhenCollapsed = true
    /// 시트를 담는 영역 높이를 받아 단계별 높이를 정한다.
    let heights: (CGFloat) -> SheetHeights
    @ViewBuilder var content: Content

    /// 끄는 동안 위로 움직인 거리(+면 위)
    @State private var dragOffset: CGFloat = 0
    @State private var dragMode: DragMode?
    @State private var scrollState = SheetScrollState()

    private enum DragMode {
        /// 시트를 움직인다
        case sheet
        /// 안쪽 스크롤에 맡긴다
        case passThrough
    }

    /// 시트 윗부분 이 높이 안에서 시작한 드래그는 펼침에서도 언제나 시트를 움직인다(손잡이 영역).
    private let handleArea: CGFloat = 36
    /// 이만큼 이상 끌면 가까운 단계가 제자리여도 한 단계 옮긴다.
    private static var stepDistance: CGFloat { 60 }

    var body: some View {
        GeometryReader { proxy in
            let heights = heights(proxy.size.height)
            let height = displayedHeight(heights)
            BottomSheetContainer(handleTopPadding: handleTopPadding) {
                content
                    .opacity(fadesContentWhenCollapsed ? contentOpacity(height, heights) : 1)
                    .allowsHitTesting(!fadesContentWhenCollapsed || detent != .collapsed)
            }
            .frame(height: height)
            .overlay(alignment: .top) { handleAccessibility }
            .simultaneousGesture(dragGesture(heights))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .environment(scrollState)
        .onAppear { scrollState.isExpanded = detent == .expanded }
        .onChange(of: detent) { _, newValue in
            scrollState.isExpanded = newValue == .expanded
        }
    }

    /// 접힘 높이에서 0, 그보다 80pt 위부터 1
    private func contentOpacity(_ height: CGFloat, _ heights: SheetHeights) -> Double {
        min(max((height - heights.collapsed) / 80, 0), 1)
    }

    /// 끝 단계 밖으로 끌면 고무줄처럼 덜 움직인다.
    private func displayedHeight(_ heights: SheetHeights) -> CGFloat {
        let raw = heights.height(for: detent) + dragOffset
        let low = heights.collapsed, high = heights.expanded
        if raw > high { return high + rubberBand(raw - high) }
        if raw < low { return max(low - rubberBand(low - raw), 0) }
        return raw
    }

    private func rubberBand(_ overshoot: CGFloat) -> CGFloat {
        let limit: CGFloat = 60
        return limit * (1 - 1 / (overshoot / limit + 1))
    }

    private func dragGesture(_ heights: SheetHeights) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragMode == nil {
                    dragMode = decideMode(for: value)
                }
                guard dragMode == .sheet else { return }
                dragOffset = -value.translation.height
            }
            .onEnded { value in
                defer { dragMode = nil }
                guard dragMode == .sheet else { return }
                let projected = heights.height(for: detent) - value.predictedEndTranslation.height
                var target = SheetDetent.allCases.min {
                    abs(heights.height(for: $0) - projected) < abs(heights.height(for: $1) - projected)
                } ?? detent
                // 가장 가까운 단계가 제자리여도 일정 거리 이상 끌었으면 그 방향으로 한 단계 옮긴다.
                let moved = -value.translation.height
                if target == detent, abs(moved) > Self.stepDistance {
                    target = (moved > 0 ? detent.next : detent.previous) ?? detent
                }
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    detent = target
                    dragOffset = 0
                }
            }
    }

    private func decideMode(for value: DragGesture.Value) -> DragMode {
        let dx = value.translation.width, dy = value.translation.height
        // 가로로 끄는 건 안쪽 가로 스크롤(후기 카드 등) 몫
        guard abs(dy) > abs(dx) else { return .passThrough }
        if value.startLocation.y < handleArea { return .sheet }
        guard detent == .expanded else { return .sheet }
        // 펼침: 목록이 맨 위에서 아래로 끌 때만 시트를 내린다.
        return scrollState.isAtTop && dy > 0 ? .sheet : .passThrough
    }

    /// VoiceOver는 끌 수 없어서 손잡이를 위아래로 조절하는 요소로 둔다.
    private var handleAccessibility: some View {
        Color.clear
            .frame(height: handleArea)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel("시트 높이")
            .accessibilityValue(detent.accessibilityName)
            .accessibilityHint("위아래로 쓸어 시트를 올리거나 내려요")
            .accessibilityAdjustableAction { direction in
                let target: SheetDetent? = switch direction {
                case .increment: detent.next
                case .decrement: detent.previous
                @unknown default: nil
                }
                if let target {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) { detent = target }
                }
            }
    }
}

/// 시트와 안쪽 스크롤이 주고받는 상태
@Observable
final class SheetScrollState {
    /// 펼침일 때만 안쪽 스크롤을 허용한다.
    var isExpanded = false
    /// 안쪽 스크롤이 맨 위인지
    var isAtTop = true
}

/// `DraggableBottomSheet` 안에서 쓰는 세로 스크롤. 펼침에서만 스크롤되고, 펼침을 벗어나면 맨 위로 되돌린다.
/// 시트 밖에서 쓰면 일반 ScrollView와 같다.
struct SheetScrollView<Content: View>: View {
    @Environment(SheetScrollState.self) private var state: SheetScrollState?
    @ViewBuilder var content: Content

    private let spaceName = "SheetScrollView"
    private let topID = "SheetScrollView.top"

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(topID)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: SheetScrollTopKey.self,
                                    value: proxy.frame(in: .named(spaceName)).minY
                                )
                            }
                        }
                    content
                }
            }
            .coordinateSpace(.named(spaceName))
            .scrollDisabled(state.map { !$0.isExpanded } ?? false)
            .onPreferenceChange(SheetScrollTopKey.self) { minY in
                state?.isAtTop = minY >= -1
            }
            .onChange(of: state?.isExpanded) { _, isExpanded in
                if isExpanded == false {
                    withAnimation { reader.scrollTo(topID, anchor: .top) }
                }
            }
        }
    }
}

private struct SheetScrollTopKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
