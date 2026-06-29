//
//  SymphoGlyph.swift
//  Sympho
//
//  Shared rendering + editing for the optional emoji / SF Symbol glyph that
//  tracks, modules, nodes and projects (and domains) can carry.
//

import SwiftUI

/// Resolves and renders an entity's glyph: an emoji takes precedence, then an
/// SF Symbol name, then a caller-supplied fallback symbol.
struct SymphoGlyphView: View {
    var emoji: String
    var iconName: String
    /// SF Symbol used when neither an emoji nor an `iconName` is set.
    var fallbackSystemName: String
    var size: CGFloat = 15

    private var trimmedEmoji: String { emoji.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedIcon: String { iconName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        if !trimmedEmoji.isEmpty {
            Text(trimmedEmoji)
                .font(.system(size: size * 0.95))
        } else {
            Image(systemName: trimmedIcon.isEmpty ? fallbackSystemName : trimmedIcon)
                .font(.system(size: size, weight: .medium))
        }
    }
}

/// Curated quick-pick palette of emojis that fit learning / engineering content.
enum SymphoEmojiPalette {
    static let quickPicks: [String] = [
        "🤖", "⚙️", "🔧", "🛠️", "🔩", "⚡️", "🔌", "🧲",
        "📐", "📏", "🧮", "📊", "📈", "🧪", "🔬", "🧠",
        "💡", "🛰️", "🚀", "🛸", "✈️", "🚗", "🛞", "🦾",
        "🦿", "🕹️", "💻", "🖥️", "📡", "🎯", "🧩", "🔭",
        "🔋", "🌡️", "💧", "🔥", "🌀", "📦", "🏗️", "🛡️",
    ]
}
