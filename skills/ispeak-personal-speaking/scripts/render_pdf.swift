import AppKit
import CoreGraphics
import CoreText
import Foundation

struct Block: Decodable {
    let style: String
    let text: String
    var key: String?
    var pageBreak: Bool?
    var keepWithNext: Bool?
}
let args = CommandLine.arguments
if args.count != 4 { fatalError("Usage: render_pdf.swift layout.json Guide.pdf page-map.json") }
let blocks = try JSONDecoder().decode([Block].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let output = URL(fileURLWithPath: args[2])
var pageRect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
guard let pdf = CGContext(output as CFURL, mediaBox: &pageRect, nil) else { fatalError("Cannot create PDF") }
let margin: CGFloat = 48
let width = pageRect.width - margin * 2
let bottom: CGFloat = 52
let top = pageRect.height - 52
var cursor = top
var page = 0
var mapping: [String: Int] = [:]
var pageHasContent = false

func styled(_ block: Block) -> NSAttributedString {
    let size: CGFloat
    let weight: NSFont.Weight
    switch block.style {
    case "title": size = 30; weight = .semibold
    case "heading": size = 24; weight = .medium
    case "grammar": size = 16; weight = .semibold
    case "mono": size = 11; weight = .medium
    case "note": size = 10; weight = .regular
    default: size = 11; weight = .regular
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = block.style == "example" ? 4 : 3
    paragraph.paragraphSpacing = 2
    let cjkName = ["title", "grammar"].contains(block.style) ? "PingFangSC-Semibold" : block.style == "heading" ? "PingFangSC-Medium" : "PingFangSC-Regular"
    let cjkFont = NSFont(name: cjkName, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    let font = block.style == "mono" ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : cjkFont
    let s = NSMutableAttributedString(string: block.text, attributes: [.font: font, .foregroundColor: NSColor(calibratedRed: 0.13, green: 0.24, blue: 0.21, alpha: 1), .paragraphStyle: paragraph])
    if block.style == "mono" {
        let ns = block.text as NSString
        for index in 0..<ns.length where ns.character(at: index) >= 0x2E80 {
            s.addAttribute(.font, value: cjkFont, range: NSRange(location: index, length: 1))
        }
    }
    if block.style == "example" {
        let lines = block.text.components(separatedBy: "\n")
        if lines.count >= 3 {
            let labelRange = NSRange(location: 0, length: (lines[0] as NSString).length)
            s.addAttributes([.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.secondaryLabelColor], range: labelRange)
            let enStart = (lines[0] as NSString).length + 1
            let enLength = (lines[1] as NSString).length
            s.addAttribute(.font, value: NSFont(name: "Georgia", size: 13) ?? NSFont.systemFont(ofSize: 13), range: NSRange(location: enStart, length: enLength))
        }
    }
    return s
}
func draw(_ string: NSAttributedString, in rect: CGRect, range: CFRange) -> CTFrame {
    let setter = CTFramesetterCreateWithAttributedString(string)
    let frame = CTFramesetterCreateFrame(setter, range, CGPath(rect: rect, transform: nil), nil)
    pdf.textMatrix = .identity
    CTFrameDraw(frame, pdf)
    return frame
}
func finishPage() {
    if page == 0 { return }
    let footer = NSAttributedString(string: "iSpeak · PERSONAL SPEAKING                                      \(page)", attributes: [.font:NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),.foregroundColor:NSColor.gray])
    _ = draw(footer, in: CGRect(x: margin, y: 22, width: width, height: 17), range: CFRange(location: 0, length: 0))
    pdf.endPDFPage()
}
func beginPage() {
    finishPage(); page += 1; pdf.beginPDFPage(nil); cursor = top; pageHasContent = false
}
beginPage()
for (blockIndex, block) in blocks.enumerated() {
    let content = styled(block)
    let setter = CTFramesetterCreateWithAttributedString(content)
    let measure = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: content.length), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil)
    let height = ceil(measure.height) + 8
    var followingReserve: CGFloat = block.keepWithNext == true ? 72 : 0
    if block.style == "grammar" {
        followingReserve = 0
        // Keep the grammar title, pattern, explanation and first bilingual pair together.
        for next in blocks.suffix(from: blockIndex + 1) {
            if next.style == "grammar" || next.pageBreak == true { break }
            let nextText = styled(next)
            let nextSetter = CTFramesetterCreateWithAttributedString(nextText)
            let nextSize = CTFramesetterSuggestFrameSizeWithConstraints(nextSetter, CFRange(location: 0, length: nextText.length), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil)
            followingReserve += ceil(nextSize.height) + 18
            if next.style == "example" { break }
        }
    }
    if (block.pageBreak == true && pageHasContent) || (height + followingReserve <= top - bottom && cursor - height - followingReserve < bottom) { beginPage() }
    if let key = block.key { mapping[key] = page }
    if height <= top - bottom {
        if cursor - height < bottom { beginPage(); if let key = block.key { mapping[key] = page } }
        _ = draw(content, in: CGRect(x: margin, y: cursor - height, width: width, height: height), range: CFRange(location: 0, length: content.length))
        cursor -= height + (block.style == "example" ? 9 : 10)
        pageHasContent = true
    } else {
        // Long appendices continue across pages; every iteration consumes actual UTF-16 text.
        var location = 0
        while location < content.length {
            if cursor - bottom < 45 { beginPage() }
            let frame = draw(content, in: CGRect(x: margin, y: bottom, width: width, height: cursor - bottom), range: CFRange(location: location, length: content.length - location))
            let visible = CTFrameGetVisibleStringRange(frame)
            if visible.length == 0 { fatalError("PDF layout failed to consume text") }
            location += visible.length; pageHasContent = true
            if location < content.length { beginPage() } else {
                let lines = CTFrameGetLines(frame) as! [CTLine]
                var origins = Array(repeating: CGPoint.zero, count: lines.count)
                CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
                cursor = bottom + (origins.last?.y ?? 0) - 20
            }
        }
    }
}
finishPage(); pdf.closePDF()
let encoded = try JSONSerialization.data(withJSONObject: mapping, options: [.prettyPrinted, .sortedKeys])
try encoded.write(to: URL(fileURLWithPath: args[3]), options: .atomic)
print("Rendered \(page) PDF pages.")
