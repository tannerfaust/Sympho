//
//  SymphoMarkdownNoteEditor.swift
//  Sympho
//

import SwiftUI
#if os(macOS)
import AppKit
import MarkdownEngine
#endif

// MARK: - Read-only note body

struct SymphoNoteBody: View {
    let text: String
    var placeholder: String = "No notes yet."
    var lineLimit: Int? = nil
    var font: Font = SymphoNoteTypography.readingFont

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if trimmed.isEmpty {
                Text(placeholder)
                    .font(font)
                    .italic()
                    .foregroundStyle(SymphoTheme.secondaryText)
            } else if let attributed = try? AttributedString(markdown: trimmed) {
                Text(attributed)
                    .font(font)
                    .lineSpacing(SymphoNoteTypography.readingLineSpacing)
                    .foregroundStyle(SymphoTheme.primaryText)
            } else {
                Text(trimmed)
                    .font(font)
                    .lineSpacing(SymphoNoteTypography.readingLineSpacing)
                    .foregroundStyle(SymphoTheme.primaryText)
            }
        }
        .lineLimit(lineLimit)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}

// MARK: - Markdown editor

struct MarkdownNoteEditor: View {
    @Binding var text: String
    let documentId: String
    var placeholder: String = SymphoNoteTypography.editorPlaceholder

    var body: some View {
        #if os(macOS)
        NativeTextViewWrapper(
            text: $text,
            configuration: SymphoMarkdownEditorConfiguration.value,
            fontName: SymphoNoteTypography.bodyFont.fontName,
            fontSize: SymphoNoteTypography.bodyFontSize,
            documentId: documentId,
            placeholder: NSAttributedString(
                string: placeholder,
                attributes: SymphoNoteTypography.placeholderAttributes
            )
        )
        #else
        TextEditor(text: $text)
            .font(SymphoNoteTypography.readingFont)
            .padding(14)
        #endif
    }
}

#if os(macOS)
enum SymphoMarkdownEditorConfiguration {
    static var value: MarkdownEditorConfiguration {
        var config = MarkdownEditorConfiguration.default
        config.readingWidth = 680
        config.textInsets = TextInsets(horizontal: 22, vertical: 22)
        config.paragraph = ParagraphStyle(spacingFactor: 0.35, lineHeightExtraSpacing: 5)
        config.headings = HeadingStyle(
            fontMultipliers: [1.85, 1.45, 1.2, 1.05, 0.95, 0.9],
            topSpacingEm: [0.45, 0.35, 0.28, 0.22, 0.18, 0.14]
        )
        config.theme = MarkdownEditorTheme(
            bodyText: .labelColor,
            mutedText: .secondaryLabelColor,
            disabledText: .tertiaryLabelColor,
            headingMarker: .tertiaryLabelColor,
            link: .linkColor,
            incompleteLink: .systemBlue,
            findMatchHighlight: .systemYellow,
            findCurrentMatchHighlight: .systemYellow,
            latexLightModeText: .labelColor,
            latexDarkModeText: .labelColor,
            strikethroughColor: .secondaryLabelColor
        )
        return config
    }
}
#endif
