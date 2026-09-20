import SwiftUI

struct MarkdownMessage: View {
    let text: String
    struct Block { var text: String; var code: Bool; var level: Int = 0 }
    private var blocks: [Block] {
        var result: [Block] = []; var code = false; var buffer = ""
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if code { result.append(Block(text: buffer, code: true)); buffer = "" }
                code.toggle(); continue
            }
            if code { buffer += (buffer.isEmpty ? "" : "\n") + line; continue }
            let level = line.prefix(while: { $0 == "#" }).count
            result.append(Block(text: level > 0 && level <= 6 ? String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces) : line, code: false, level: level <= 6 ? level : 0))
        }
        if code { result.append(Block(text: buffer, code: true)) }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.code {
                    VStack(alignment: .leading) {
                        Button("Копировать код", systemImage: "doc.on.doc") { UIPasteboard.general.string = block.text }.font(.caption)
                        ScrollView(.horizontal) { Text(verbatim: block.text).font(.system(.callout, design: .monospaced)).textSelection(.enabled) }
                    }.padding(12).background(Color.black.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(.init(block.text)).font(block.level > 0 ? .system(size: CGFloat(max(17, 29 - block.level * 2)), weight: .bold) : .body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
