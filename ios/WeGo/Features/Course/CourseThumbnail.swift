import MapKit
import os
import SwiftUI
import UIKit

/// 코스 카드 썸네일(Figma 402:306, 카드 안 148x95).
///
/// 보여 주는 순서
/// 1. 사용자가 이 코스에 사진을 넣었으면 사진(CoursePhotoStore)
/// 2. 없으면 코스 경로를 그린 지도 이미지(CourseMapSnapshotter, 만들어 둔 것은 다시 쓴다)
/// 3. 지도 이미지를 만드는 동안이나 만들 수 없을 때는 연회색 바탕에 경로 선만 그린 그림(디자인 시안과 같은 모양)
struct CourseThumbnail: View {
    let course: Course

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                WeGoColor.gray100
                CourseRouteSketch(coordinates: course.coordinates)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: course.id) {
            image = await Self.loadImage(for: course, size: CourseThumbnailStyle.size)
        }
        .accessibilityHidden(true)
    }

    private static func loadImage(for course: Course, size: CGSize) async -> UIImage? {
        if let photo = CoursePhotoStore.shared.photo(for: course.id) {
            return photo
        }
        return await CourseMapSnapshotter.shared.image(for: course, size: size)
    }
}

/// 썸네일 크기와 경로 선, 점 모양(디자인 시안 기준)
enum CourseThumbnailStyle {
    static let size = CGSize(width: 148, height: 95)
    static let lineWidth: CGFloat = 2
    static let startDotSize: CGFloat = 11
    static let endDotSize: CGFloat = 12
    static let lineColor = WeGoColor.primaryLight
    static let startColor = WeGoColor.sky
    static let endColor = WeGoColor.red
}

/// 지도 없이 경로 모양만 그린 그림. 코스 좌표를 칸에 맞게 늘려 그린다(가로세로 비율 유지).
struct CourseRouteSketch: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Canvas { context, size in
            let points = CourseRouteGeometry.fit(coordinates, in: CGRect(origin: .zero, size: size))
            guard let first = points.first, let last = points.last else { return }
            var path = Path()
            path.addLines(points)
            context.stroke(
                path,
                with: .color(CourseThumbnailStyle.lineColor),
                style: StrokeStyle(lineWidth: CourseThumbnailStyle.lineWidth, lineCap: .round, lineJoin: .round)
            )
            context.fill(dot(at: first, size: CourseThumbnailStyle.startDotSize), with: .color(CourseThumbnailStyle.startColor))
            context.fill(dot(at: last, size: CourseThumbnailStyle.endDotSize), with: .color(CourseThumbnailStyle.endColor))
        }
    }

    private func dot(at point: CGPoint, size: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size))
    }
}

/// 경로 좌표를 화면 좌표로 옮기는 계산
enum CourseRouteGeometry {
    /// 좌표 묶음을 rect 안에 가로세로 비율을 지켜 가운데 맞춘 점들로 바꾼다. 북쪽이 위.
    /// 경도 1도는 위도에 따라 짧아지므로 cos(위도)를 곱해 실제 모양에 가깝게 한다.
    static func fit(_ coordinates: [CLLocationCoordinate2D], in rect: CGRect) -> [CGPoint] {
        guard let first = coordinates.first else { return [] }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let lonScale = cos((minLat + maxLat) / 2 * .pi / 180)
        let width = (maxLon - minLon) * lonScale
        let height = maxLat - minLat
        guard width > 0 || height > 0 else {
            return coordinates.map { _ in CGPoint(x: rect.midX, y: rect.midY) }
        }
        let scale = min(
            width > 0 ? rect.width / width : .infinity,
            height > 0 ? rect.height / height : .infinity
        )
        let offsetX = rect.minX + (rect.width - width * scale) / 2
        let offsetY = rect.minY + (rect.height - height * scale) / 2
        return coordinates.map { coordinate in
            CGPoint(
                x: offsetX + (coordinate.longitude - minLon) * lonScale * scale,
                y: offsetY + (maxLat - coordinate.latitude) * scale
            )
        }
    }

    /// 경로 전체가 여백(padding, 비율)을 두고 들어오는 지도 영역. 좌표가 없으면 nil
    static func region(fitting coordinates: [CLLocationCoordinate2D], padding: Double = 1.6) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        // 아주 짧은 코스도 길과 동네가 보이도록 최소 약 300m는 보여 준다.
        let minimumSpan = 0.003
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * padding, minimumSpan),
                longitudeDelta: max((maxLon - minLon) * padding, minimumSpan)
            )
        )
    }
}

/// 코스 경로를 그린 지도 이미지를 만들고 메모리에 담아 둔다(같은 코스는 다시 만들지 않음).
@MainActor
final class CourseMapSnapshotter {
    static let shared = CourseMapSnapshotter()

    private let cache = NSCache<NSString, UIImage>()
    private let logger = Logger(subsystem: "com.matuna01.wego", category: "CourseThumbnail")

    private init() {
        cache.countLimit = 100
    }

    func image(for course: Course, size: CGSize) async -> UIImage? {
        let key = "\(course.id)-\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let coordinates = course.coordinates
        guard coordinates.count > 1, let region = CourseRouteGeometry.region(fitting: coordinates) else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.mapType = .mutedStandard
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false
        do {
            let snapshot = try await MKMapSnapshotter(options: options).start()
            let image = Self.draw(route: coordinates, on: snapshot)
            cache.setObject(image, forKey: key)
            return image
        } catch {
            logger.error("코스 지도 이미지 만들기 실패: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 지도 위에 경로 선과 출발, 도착 점을 그린다.
    private static func draw(route coordinates: [CLLocationCoordinate2D], on snapshot: MKMapSnapshotter.Snapshot) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let points = coordinates.map { snapshot.point(for: $0) }
            let cg = context.cgContext
            cg.setLineWidth(CourseThumbnailStyle.lineWidth)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.setStrokeColor(UIColor(CourseThumbnailStyle.lineColor).cgColor)
            cg.addLines(between: points)
            cg.strokePath()
            if let first = points.first {
                fillDot(cg, at: first, size: CourseThumbnailStyle.startDotSize, color: UIColor(CourseThumbnailStyle.startColor))
            }
            if let last = points.last {
                fillDot(cg, at: last, size: CourseThumbnailStyle.endDotSize, color: UIColor(CourseThumbnailStyle.endColor))
            }
        }
    }

    private static func fillDot(_ cg: CGContext, at point: CGPoint, size: CGFloat, color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size))
    }
}

/// 사용자가 코스에 넣은 사진. 기기(Application Support/CoursePhotos)에만 저장한다.
/// 사진을 넣는 화면은 아직 없고, 넣으면 썸네일이 지도 이미지 대신 사진을 보여 준다.
final class CoursePhotoStore {
    static let shared = CoursePhotoStore()

    private let directory: URL
    private let logger = Logger(subsystem: "com.matuna01.wego", category: "CoursePhoto")

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoursePhotos", isDirectory: true)
    }

    func photo(for courseID: Course.ID) -> UIImage? {
        let url = fileURL(for: courseID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func hasPhoto(for courseID: Course.ID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: courseID).path)
    }

    /// 사진을 JPEG로 저장한다. 같은 코스에 다시 넣으면 바꾼다.
    @discardableResult
    func save(_ image: UIImage, for courseID: Course.ID) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(for: courseID), options: .atomic)
            return true
        } catch {
            logger.error("코스 사진 저장 실패: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func removePhoto(for courseID: Course.ID) {
        try? FileManager.default.removeItem(at: fileURL(for: courseID))
    }

    /// 코스 ID에서 파일 이름에 쓸 수 없는 글자를 뺀 경로
    func fileURL(for courseID: Course.ID) -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safe = String(courseID.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return directory.appendingPathComponent("\(safe).jpg")
    }
}
