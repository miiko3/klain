import SwiftUI
import AVKit

struct GeneratedMediaView: View {
    let media: GeneratedMedia
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var error: String?
    var body: some View {
        VStack {
            if let image { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)) }
            else if let player { VideoPlayer(player: player).frame(height: 240) }
            else if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
            else { ProgressView("Загрузка медиа…") }
            if let url = URL(string: media.url), url.scheme == "https" { Link("Открыть оригинал", destination: url).font(.caption) }
        }.task(id: media.url) {
            do {
                if media.kind == "video" {
                    guard let url = URL(string: media.url), url.scheme == "https" else { throw URLError(.unsupportedURL) }
                    player = AVPlayer(url: url)
                } else {
                    let data: Data
                    if media.url.hasPrefix("data:image/"), let comma = media.url.firstIndex(of: ","), let decoded = Data(base64Encoded: String(media.url[media.url.index(after: comma)...])) { data = decoded }
                    else {
                        guard let url = URL(string: media.url), url.scheme == "https" else { throw URLError(.unsupportedURL) }
                        let (download, response) = try await URLSession.shared.data(from: url)
                        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
                        data = download
                    }
                    guard let decoded = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                    image = decoded
                }
            } catch { self.error = "Не удалось открыть медиа: \(error.localizedDescription)" }
        }.onDisappear { player?.pause() }
    }
}
