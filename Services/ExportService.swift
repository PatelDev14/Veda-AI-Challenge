import UIKit
import SwiftUI

// MARK: - Export Service

@MainActor
final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - Strip markdown so PDF doesn't show raw **bold** or ## symbols
    private func stripMarkdown(_ text: String) -> String {
        var result = text
        // Headers
        result = result.replacingOccurrences(of: #"#{1,6}\s"#, with: "", options: .regularExpression)
        // Bold/italic
        result = result.replacingOccurrences(of: #"\*{1,3}([^*]+)\*{1,3}"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_{1,3}([^_]+)_{1,3}"#, with: "$1", options: .regularExpression)
        // Bullet points → clean dash
        result = result.replacingOccurrences(of: #"^\s*[-*+]\s"#, with: "• ", options: .regularExpression)
        // Numbered list cleanup
        result = result.replacingOccurrences(of: #"^\s*\d+\.\s"#, with: "", options: .regularExpression)
        // Code blocks
        result = result.replacingOccurrences(of: #"```[^`]*```"#, with: "[code block]", options: .regularExpression)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        return result
    }

    // MARK: - Export as PDF
    func exportAsPDF(messages: [Message]) -> URL? {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Veda_Conversation_\(Int(Date().timeIntervalSince1970)).pdf")

        do {
            try renderer.writePDF(to: tempURL) { ctx in
                // ── Helper: begin a new page and reset Y ──────────────────
                func newPage() -> CGFloat {
                    ctx.beginPage()
                    return margin
                }

                // ── Helper: draw text and return new Y offset ─────────────
                func draw(string: NSAttributedString, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
                    let rect = CGRect(x: x, y: y, width: width, height: .greatestFiniteMagnitude)
                    let boundingRect = string.boundingRect(
                        with: CGSize(width: width, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    string.draw(in: CGRect(x: x, y: y, width: width, height: ceil(boundingRect.height)))
                    return y + ceil(boundingRect.height)
                }

                var y: CGFloat = newPage()

                // ── Title block ───────────────────────────────────────────
                let titleStr = NSAttributedString(string: "Veda AI", attributes: [
                    .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                    .foregroundColor: UIColor.systemOrange
                ])
                y = draw(string: titleStr, x: margin, y: y, width: contentWidth) + 4

                let subtitleStr = NSAttributedString(
                    string: "Conversation — " + Date().formatted(date: .long, time: .shortened),
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor.systemGray
                    ]
                )
                y = draw(string: subtitleStr, x: margin, y: y, width: contentWidth) + 16

                // Divider line
                let divider = UIBezierPath()
                divider.move(to: CGPoint(x: margin, y: y))
                divider.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                divider.lineWidth = 0.5
                UIColor.systemGray4.setStroke()
                divider.stroke()
                y += 20

                // ── Messages ──────────────────────────────────────────────
                let nonEmpty = messages.filter { !$0.content.isEmpty }

                for message in nonEmpty {
                    let isUser = message.isUser
                    let roleColor: UIColor = isUser ? .systemBlue : .systemOrange
                    let cleanContent = stripMarkdown(message.content)

                    // Role label
                    let roleStr = NSAttributedString(
                        string: isUser ? "You" : "Veda",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                            .foregroundColor: roleColor
                        ]
                    )

                    // Content text
                    let contentStr = NSAttributedString(
                        string: cleanContent,
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 13),
                            .foregroundColor: UIColor.darkText,
                            .paragraphStyle: {
                                let ps = NSMutableParagraphStyle()
                                ps.lineSpacing = 3
                                ps.paragraphSpacing = 2
                                return ps
                            }()
                        ]
                    )

                    // Calculate total height for this message block
                    let contentHeight = contentStr.boundingRect(
                        with: CGSize(width: contentWidth - 16, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    ).height

                    let blockHeight = 16 + ceil(contentHeight) + 20 // role + content + gap

                    // New page if this block won't fit
                    if y + blockHeight > pageHeight - margin {
                        y = newPage()
                    }

                    // Draw role label
                    y = draw(string: roleStr, x: margin, y: y, width: contentWidth) + 4

                    // Draw content
                    y = draw(string: contentStr, x: margin + 8, y: y, width: contentWidth - 16)

                    // Separator line between messages
                    y += 10
                    let sep = UIBezierPath()
                    sep.move(to: CGPoint(x: margin, y: y))
                    sep.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                    sep.lineWidth = 0.3
                    UIColor.systemGray5.setStroke()
                    sep.stroke()
                    y += 14
                }
            }
            return tempURL
        } catch {
            print("❌ PDF export failed: \(error)")
            return nil
        }
    }

    // MARK: - Export as Plain Text
    func exportAsText(messages: [Message]) -> String {
        var lines = ["Veda AI Conversation", Date().formatted(date: .long, time: .shortened), "---", ""]
        for msg in messages where !msg.content.isEmpty {
            lines.append(msg.isUser ? "You:" : "Veda:")
            lines.append(msg.content)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Export Button
struct ExportButton: View {
    let messages: [Message]
    @State private var exportItem: ExportItem? = nil

    var body: some View {
        Button {
            if let url = ExportService.shared.exportAsPDF(messages: messages) {
                exportItem = ExportItem(url: url)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14))
                .foregroundStyle(.orange.opacity(0.8))
                .padding(12)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.orange.opacity(0.2), lineWidth: 0.5))
                )
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(url: item.url)
        }
    }
}

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
