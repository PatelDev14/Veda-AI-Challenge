import SwiftUI

// MARK: - Main Bubble View
struct MessageBubbleView: View {
    let message: Message
    @State private var showTimestamp = false
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 5) {
            
            if message.isUser {
                userBubble
            } else {
                assistantContent
            }
            
            if showTimestamp {
                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.horizontal, 6)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) { showTimestamp.toggle() }
        }
    }
    
    // MARK: - User Bubble
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let img = message.attachedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 220, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            
            if !message.content.isEmpty {
                Text(message.content)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                            )
                    )
            }
        }
    }
    
    // MARK: - Assistant Content
    private var assistantContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Veda label
            HStack(spacing: 5) {
                Text("✦")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange.opacity(0.55))
                Text("VEDA")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.orange.opacity(0.5))
            }
            .padding(.leading, 2)
            .padding(.bottom, 5)
            
            if message.content.isEmpty {
                EmptyView()
            } else if message.isError {
                errorView
            } else {
                MarkdownContentView(text: message.content)
                
                // Copy button
                HStack {
                    Spacer()
                    Button {
                        UIPasteboard.general.string = message.content
                        withAnimation(.spring(response: 0.3)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(copied ? Color.green.opacity(0.7) : Color.white.opacity(0.18))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.04)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
        }
        .padding(.trailing, 36)
    }
    
    private var errorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(.red.opacity(0.7))
            Text(message.content)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.red.opacity(0.75))
                .lineSpacing(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - Markdown Block Model
enum MarkdownBlock {
    case heading(level: Int, content: String)
    case bulletPoint(content: String, depth: Int)
    case numberedPoint(content: String, number: Int)
    case paragraph(content: String)
    case codeBlock(content: String)
    case blockquote(content: String)
    case divider
    case emptyLine
}

// MARK: - Parser
func parseBlocks(_ text: String) -> [MarkdownBlock] {
    let lines = text.components(separatedBy: "\n")
    var blocks: [MarkdownBlock] = []
    var i = 0
    
    while i < lines.count {
        let raw = lines[i]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        
        // Code fence
        if trimmed.hasPrefix("```") {
            var codeLines: [String] = []
            i += 1
            while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }
            blocks.append(.codeBlock(content: codeLines.joined(separator: "\n")))
            i += 1
            continue
        }
        
        // Divider
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            blocks.append(.divider); i += 1; continue
        }
        
        // Headings
        if trimmed.hasPrefix("### ") {
            blocks.append(.heading(level: 3, content: String(trimmed.dropFirst(4)))); i += 1; continue
        }
        if trimmed.hasPrefix("## ") {
            blocks.append(.heading(level: 2, content: String(trimmed.dropFirst(3)))); i += 1; continue
        }
        if trimmed.hasPrefix("# ") {
            blocks.append(.heading(level: 1, content: String(trimmed.dropFirst(2)))); i += 1; continue
        }
        
        // Blockquote
        if trimmed.hasPrefix("> ") {
            blocks.append(.blockquote(content: String(trimmed.dropFirst(2)))); i += 1; continue
        }
        
        // Bullets — detect indent depth
        let leadingSpaces = raw.prefix(while: { $0 == " " }).count
        let depth = leadingSpaces / 2
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
            let content = String(trimmed.dropFirst(2))
            blocks.append(.bulletPoint(content: content, depth: depth)); i += 1; continue
        }
        
        // Numbered list (Legacy Swift support for regex)
        if let firstDotIndex = trimmed.firstIndex(of: "."),
           let num = Int(trimmed[..<firstDotIndex]) {
            let content = trimmed[trimmed.index(after: firstDotIndex)...].trimmingCharacters(in: .whitespaces)
            blocks.append(.numberedPoint(content: content, number: num))
            i += 1
            continue
        }
        
        // Empty line
        if trimmed.isEmpty {
            if let last = blocks.last, case .emptyLine = last { } else {
                blocks.append(.emptyLine)
            }
            i += 1; continue
        }
        
        // Paragraph
        var paragraphLines: [String] = []
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix("- ") || t.hasPrefix("* ") ||
               t.hasPrefix("• ") || t.hasPrefix("> ") || t.hasPrefix("```") || t == "---" { break }
            paragraphLines.append(lines[i])
            i += 1
        }
        if !paragraphLines.isEmpty {
            blocks.append(.paragraph(content: paragraphLines.joined(separator: " ")))
        }
    }
    return blocks
}

// MARK: - Markdown Content View
struct MarkdownContentView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(parseBlocks(text).enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }
    
    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            InlineStyledText(text: content)
                .styledAs(headingStyle(level))
                .padding(.top, level == 1 ? 14 : 9)
                .padding(.bottom, 3)
            
        case .bulletPoint(let content, let depth):
            BulletRowView(content: content, depth: depth)
                .padding(.vertical, 3)
            
        case .numberedPoint(let content, let number):
            NumberedRowView(content: content, number: number)
                .padding(.vertical, 3)
            
        case .paragraph(let content):
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                InlineStyledText(text: content)
                    .padding(.vertical, 4)
            }
            
        case .codeBlock(let content):
            CodeBlockView(code: content)
                .padding(.vertical, 6)
            
        case .blockquote(let content):
            BlockquoteView(text: content)
                .padding(.vertical, 4)
            
        case .divider:
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.orange.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.vertical, 10)
            
        case .emptyLine:
            Color.clear.frame(height: 7)
        }
    }
    
    private func headingStyle(_ level: Int) -> HeadingStyle {
        switch level {
        case 1: return HeadingStyle(size: 18, weight: .bold, color: Color.orange.opacity(0.9))
        case 2: return HeadingStyle(size: 16, weight: .semibold, color: Color.orange.opacity(0.75))
        default: return HeadingStyle(size: 14, weight: .semibold, color: Color.white.opacity(0.8))
        }
    }
}

struct HeadingStyle {
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
}

// MARK: - Bullet Row
struct BulletRowView: View {
    let content: String
    let depth: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                if depth == 0 {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.9), Color.yellow.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 14, height: 22, alignment: .center)
            
            InlineStyledText(text: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(depth) * 16)
    }
}

// MARK: - Numbered Row
struct NumberedRowView: View {
    let content: String
    let number: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.orange.opacity(0.8))
                .frame(width: 24, alignment: .trailing)
                .padding(.top, 2)
            
            InlineStyledText(text: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Code Block
struct CodeBlockView: View {
    let code: String
    @State private var copied = false
    
    // Extracting this array helps the compiler type-check faster
    private let windowButtons: [Color] = [
        .red.opacity(0.6),
        .yellow.opacity(0.6),
        .green.opacity(0.6)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineSpacing(4)
                    .padding(12)
            }
        }
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    // Breaking the header into its own sub-view further improves build times
    private var headerBar: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<windowButtons.count, id: \.self) { index in
                    Circle()
                        .fill(windowButtons[index])
                        .frame(width: 7, height: 7)
                }
            }
            
            Spacer()
            
            Button {
                UIPasteboard.general.string = code
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copied = false }
                }
            } label: {
                Text(copied ? "Copied ✓" : "Copy")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(copied ? .green.opacity(0.8) : .white.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
    }
}

// MARK: - Blockquote
struct BlockquoteView: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(colors: [Color.orange.opacity(0.6), Color.orange.opacity(0.2)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 2.5)
            
            InlineStyledText(text: text)
                .foregroundStyle(.white.opacity(0.6))
                .italic()
        }
        .padding(.leading, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Inline Styled Text
struct InlineStyledText: View {
    let text: String
    private var headingStyle: HeadingStyle? = nil
    private var forcedForeground: Color? = nil
    private var isItalic: Bool = false
    
    init(text: String) { self.text = text }
    
    func styledAs(_ style: HeadingStyle) -> InlineStyledText {
        var copy = self; copy.headingStyle = style; return copy
    }
    
    func foregroundStyle(_ color: Color) -> InlineStyledText {
        var copy = self; copy.forcedForeground = color; return copy
    }
    
    func italic() -> InlineStyledText {
        var copy = self; copy.isItalic = true; return copy
    }
    
    var body: some View {
        buildAttributed()
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var configuration: (size: CGFloat, weight: Font.Weight, color: Color) {
        let size = headingStyle?.size ?? 15
        let weight = headingStyle?.weight ?? .regular
        let color = forcedForeground ?? headingStyle?.color ?? Color.white.opacity(0.88)
        return (size, weight, color)
    }
    
    private func buildAttributed() -> Text {
        var result = Text("")
        var remaining = text
        let config = configuration
        
        while !remaining.isEmpty {
            // Bold (** or __)
            if let boldText = extractInline(from: &remaining, open: "**", close: "**") ??
                extractInline(from: &remaining, open: "__", close: "__") {
                
                let styledBold = Text(boldText)
                    .font(.system(size: config.size, weight: .bold, design: .rounded))
                    .foregroundStyle(config.color)
                
                result = result + styledBold
                continue
            }
            
            // Italic (* or _)
            if let italicText = extractInline(from: &remaining, open: "*", close: "*") ??
                extractInline(from: &remaining, open: "_", close: "_") {
                
                let styledItalic = Text(italicText)
                    .font(.system(size: config.size, weight: config.weight, design: .rounded))
                    .italic()
                    .foregroundStyle(config.color.opacity(0.8))
                
                result = result + styledItalic
                continue
            }
            
            // Inline Code (`)
            if let codeText = extractInline(from: &remaining, open: "`", close: "`") {
                
                let styledCode = Text(codeText)
                    .font(.system(size: config.size - 1.5, design: .monospaced))
                    .foregroundStyle(Color.orange.opacity(0.85))
                
                result = result + styledCode
                continue
            }
            
            // Plain character fallback
            let char = String(remaining.removeFirst())
            var plainSegment = Text(char)
                .font(.system(size: config.size, weight: config.weight, design: .rounded))
                .foregroundStyle(config.color)
            
            if isItalic {
                plainSegment = plainSegment.italic()
            }
            
            result = result + plainSegment
        }
        
        return result
    }
    
    private func extractInline(from string: inout String, open: String, close: String) -> String? {
        guard string.hasPrefix(open) else { return nil }
        let after = string.dropFirst(open.count)
        guard let closeRange = after.range(of: close) else { return nil }
        let inner = String(after[after.startIndex..<closeRange.lowerBound])
        string = String(after[closeRange.upperBound...])
        return inner
    }
}
