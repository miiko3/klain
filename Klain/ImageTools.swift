import UIKit
import UniformTypeIdentifiers

enum ImageTools {
    static func attachment(name: String, data: Data) -> Attachment? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1600
        let sourceSize = image.size
        let scale = min(1, maxSide / max(sourceSize.width, sourceSize.height))
        let target = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = rendered.jpegData(compressionQuality: 0.82) else { return nil }
        return Attachment(name: name, mime: "image/jpeg", data: jpeg)
    }

    static func isImageType(_ type: UTType?) -> Bool {
        type?.conforms(to: .image) == true
    }
}
