import SwiftUI

// Rich Markdown renderer for AI answers.
// Supports: headings, fenced code (with language), GFM tables, ordered /
// unordered / task / nested lists, blockquotes, horizontal rules, paragraphs
// and inline formatting (bold, italic, strikethrough, inline code, links,
// images). Replaces the old 37-line subset that only handled headings+code.
struct MarkdownMessage: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MDBlock.parse(text).enumerated()), id: \.offset) { _, block in
                MDBlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Block model

enum MDBlock {
    case heading(Int, String)
    case paragraph(String)
    case code(String, String)                 // code, language
    case quote([MDBlock])
    case list(ordered: Bool, items: [MDItem])
    case table(head: [String], align: [MDAlign], rows: [[String]])
    case rule

    struct MDItem { var text: String; var checked: Bool?; var children: [MDBlock] }
    enum MDAlign { case left, center, right }

    static func parse(_ raw: String) -> [MDBlock] {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var out: [MDBlock] = []
        var i = 0
        while i < lines.count {
            let line = lines[i], t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { i += 1; continue }

            // fenced code
            if let fence = t.range(of: "^```+\\s*([\\w+.#-]*)\\s*$", options: .regularExpression) {
                let lang = String(t[fence]).replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
                i += 1; var code: [String] = []
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { code.append(lines[i]); i += 1 }
                i += 1
                out.append(.code(code.joined(separator: "\n"), lang)); continue
            }
            // heading (space required so "#include" stays literal)
            if let h = t.range(of: "^(#{1,6})\\s+(.*)$", options: .regularExpression) {
                let whole = String(t[h]); let level = whole.prefix(while: { $0 == "#" }).count
                let body = String(whole.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                out.append(.heading(level, body)); i += 1; continue
            }
            // horizontal rule
            if t.range(of: "^(\\*\\s*){3,}$|^(-\\s*){3,}$|^( _\\s*){3,}$", options: .regularExpression) != nil { out.append(.rule); i += 1; continue }
            // table
            if t.contains("|"), i + 1 < lines.count, isDelimiter(lines[i + 1]) {
                let head = splitCells(t), aligns = splitCells(lines[i + 1]).map { a -> MDAlign in
                    a.hasPrefix(":") && a.hasSuffix(":") ? .center : a.hasSuffix(":") ? .right : .left
                }
                i += 2; var rows: [[String]] = []
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty && lines[i].contains("|") { rows.append(splitCells(lines[i])); i += 1 }
                out.append(.table(head: head, align: aligns, rows: rows)); continue
            }
            // blockquote
            if t.hasPrefix(">") {
                var q: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    q.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces)); i += 1
                }
                out.append(.quote(parse(q.joined(separator: "\n")))); continue
            }
            // list
            if listMarker(line) != nil { let r = parseList(lines, i, indent(of: line)); out.append(r.block); i = r.next; continue }
            // paragraph
            var para: [String] = []
            while i < lines.count {
                let x = lines[i].trimmingCharacters(in: .whitespaces)
                if x.isEmpty || x.hasPrefix("```") || x.range(of: "^#{1,6}\\s", options: .regularExpression) != nil ||
                    x.hasPrefix(">") || listMarker(lines[i]) != nil || isRule(x) ||
                    (lines[i].contains("|") && i + 1 < lines.count && isDelimiter(lines[i + 1])) { break }
                para.append(x); i += 1
            }
            if !para.isEmpty { out.append(.paragraph(para.joined(separator: "\n"))) } else { i += 1 }
        }
        return out
    }

    static func splitCells(_ r: String) -> [String] {
        r.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "|")).split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    static func isDelimiter(_ r: String) -> Bool {
        r.range(of: "^\\s*\\|?\\s*:?-{1,}:?\\s*(\\|\\s*:?-{1,}:?\\s*)+\\|?\\s*$", options: .regularExpression) != nil
    }
    static func isRule(_ r: String) -> Bool {
        r.range(of: "^(\\*\\s*){3,}$|^(-\\s*){3,}$|^( _\\s*){3,}$", options: .regularExpression) != nil
    }
    static func indent(of l: String) -> Int { l.prefix(while: { $0 == " " }).count }
    static func listMarker(_ l: String) -> (Bool, String, Int)? {
        if let m = l.range(of: "^(\\s*)([-*+])\\s+(.*)$", options: .regularExpression) {
            let s = String(l[m]); return (false, String(s.drop(while: { $0 == " " || $0 == "-" || $0 == "*" || $0 == "+" }).trimmingCharacters(in: .whitespaces)), indent(of: l))
        }
        if let m = l.range(of: "^(\\s*)(\\d+)[.)]\\s+(.*)$", options: .regularExpression) {
            let body = l[m].components(separatedBy: CharacterSet(charactersIn: ".)")).dropFirst().joined()
            return (true, body.trimmingCharacters(in: .whitespaces), indent(of: l))
        }
        return nil
    }
    static func parseList(_ lines: [String], _ start: Int, _ indent: Int) -> (block: MDBlock, next: Int) {
        var items: [MDItem] = []; var i = start; var ordered = false
        while i < lines.count {
            guard let m = listMarker(lines[i]), m.2 == indent else { break }
            ordered = m.0
            var content = m.1, checked: Bool? = nil
            if let task = content.range(of: "^\\[([ xX])\\]\\s*(.*)$", options: .regularExpression) {
                let s = String(content[task]); checked = s.contains("[x]") || s.contains("[X]")
                content = String(s.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            i += 1
            var children: [MDBlock] = []
            if i < lines.count, let nm = listMarker(lines[i]), nm.2 > indent { let r = parseList(lines, i, nm.2); children.append(r.block); i = r.next }
            items.append(MDItem(text: content, checked: checked, children: children))
            if i < lines.count, let nn = listMarker(lines[i]), nn.2 == indent { continue }
            break
        }
        return (.list(ordered: ordered, items: items), max(i, start + 1))
    }
}

// MARK: - Inline (AttributedString markdown + safe links)
// Uses the baseline initializer only — max compatibility across iOS SDKs.
func mdInline(_ raw: String) -> AttributedString {
    var s = (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
    for run in s.runs where run.link != nil { s[run.range].foregroundColor = .primary }
    return s
}

// MARK: - Block views

struct MDBlockView: View {
    let block: MDBlock
    var body: some View {
        switch block {
        case .heading(let lv, let text):
            Text(mdInline(text)).font(.system(size: CGFloat(max(17, 29 - lv * 2)), weight: .bold)).fixedSize(horizontal: false, vertical: true)
        case .paragraph(let text):
            Text(mdInline(text)).font(.body).fixedSize(horizontal: false, vertical: true)
        case .code(let code, let lang):
            VStack(alignment: .leading, spacing: 6) {
                HStack { if !lang.isEmpty { Text(lang.uppercased()).font(.caption2).foregroundStyle(.secondary) }; Spacer()
                    Button { UIPasteboard.general.string = code } label: { Label("Копировать код", systemImage: "doc.on.doc").font(.caption) } }
                ScrollView(.horizontal) { Text(verbatim: code).font(.system(.callout, design: .monospaced)).textSelection(.enabled) }
            }
            .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .quote(let blocks):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.5)).frame(width: 3)
                VStack(alignment: .leading, spacing: 4) { ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in MDBlockView(block: b) } }
            }.padding(.vertical, 4)
        case .rule:
            Divider().background(.white.opacity(0.2))
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 7) {
                        if let c = item.checked { Image(systemName: c ? "checkmark.square" : "square").foregroundStyle(.primary) }
                        else { Text(ordered ? "\(idx + 1)." : "•").foregroundStyle(.secondary) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mdInline(item.text)).font(.body).fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(item.children.enumerated()), id: \.offset) { _, b in MDBlockView(block: b).padding(.leading, 6) }
                        }
                    }
                }
            }
        case .table(let head, let align, let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow { ForEach(Array(head.enumerated()), id: \.offset) { j, c in
                        Text(mdInline(c)).font(.caption.weight(.bold)).padding(7).frame(maxWidth: .infinity, alignment: alignOf(align, j))
                            .background(.white.opacity(0.10))
                    } }
                    Divider()
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        GridRow { ForEach(Array(head.enumerated()), id: \.offset) { j, _ in
                            Text(mdInline(j < r.count ? r[j] : "")).font(.caption).padding(7).frame(maxWidth: .infinity, alignment: alignOf(align, j))
                        } }
                        Divider()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
    func alignOf(_ a: [MDBlock.MDAlign], _ j: Int) -> Alignment {
        guard j < a.count else { return .leading }
        switch a[j] { case .center: return .center; case .right: return .trailing; default: return .leading }
    }
}
