//
//  SymphoStyles.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI

struct SymphoTheme {
    #if os(macOS)
    static let primaryCanvas = Color.white
    static let elevatedCanvas = Color(nsColor: .controlBackgroundColor)
    static let secondarySurface = Color.white.opacity(0.72)
    static let controlBackground = Color(nsColor: .controlBackgroundColor)
    static let dividerColor = Color(nsColor: .separatorColor).opacity(0.42)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    #else
    static let primaryCanvas = Color.white
    static let elevatedCanvas = Color(.secondarySystemBackground)
    static let secondarySurface = Color(.secondarySystemGroupedBackground)
    static let controlBackground = Color(.secondarySystemGroupedBackground)
    static let dividerColor = Color(.separator).opacity(0.35)
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
    #endif

    static let colorActive = primaryText
    static let primaryAction = Color(red: 0.11, green: 0.11, blue: 0.10)
    static let colorBacklog = secondaryText
    static let colorMastered = Color(red: 0.12, green: 0.52, blue: 0.34)
    static let colorCritical = Color(red: 0.74, green: 0.17, blue: 0.16)

    static let gridSpacing: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let cornerRadius: CGFloat = 8
    static let controlRadius: CGFloat = 7
    static let outerPadding: CGFloat = 28
    static let sidebarWidth: CGFloat = 236
}

// MARK: - Typography

extension View {
    func editorialHeader() -> some View {
        self.font(.system(size: 28, weight: .semibold, design: .default))
            .foregroundColor(SymphoTheme.primaryText)
            .lineSpacing(2)
    }

    func editorialTitle() -> some View {
        self.font(.system(size: 15, weight: .semibold, design: .default))
            .foregroundColor(SymphoTheme.primaryText)
    }

    func editorialSubtitle() -> some View {
        self.font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundColor(SymphoTheme.primaryText)
    }

    func bodySans() -> some View {
        self.font(.system(size: 13, weight: .regular, design: .default))
            .lineSpacing(4)
            .foregroundColor(SymphoTheme.primaryText)
    }

    func metadataSans() -> some View {
        self.font(.system(size: 12, weight: .regular, design: .default))
            .foregroundColor(SymphoTheme.secondaryText)
    }

    func captionSans() -> some View {
        self.font(.system(size: 11, weight: .regular, design: .default))
            .foregroundColor(SymphoTheme.secondaryText)
    }
}

// MARK: - Surfaces

struct NativePanel: ViewModifier {
    var backgroundColor: Color = SymphoTheme.elevatedCanvas.opacity(0.66)

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius, style: .continuous)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
    }
}

struct GlassPanel: ViewModifier {
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: SymphoTheme.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
    }
}

extension View {
    func premiumCard(backgroundColor: Color = SymphoTheme.elevatedCanvas.opacity(0.66)) -> some View {
        self.modifier(NativePanel(backgroundColor: backgroundColor))
    }

    func nativePanel(backgroundColor: Color = SymphoTheme.elevatedCanvas.opacity(0.66)) -> some View {
        self.modifier(NativePanel(backgroundColor: backgroundColor))
    }

    func glassPanel(padding: CGFloat = 14) -> some View {
        self.modifier(GlassPanel(padding: padding))
    }

    func appContentBackground() -> some View {
        self.background {
            ZStack {
                SymphoTheme.primaryCanvas
                SymphoTheme.secondarySurface.opacity(0.20)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Buttons and Controls

/// Circular liquid-glass add control (matches Projects / Domains).
struct SymphoGlassAddButton: View {
    var help: String = "Add"
    var size: CGFloat = 34
    var iconSize: CGFloat = 17
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: iconSize, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(help)
    }
}

extension View {
    /// Right-click menu with Edit and Delete, matching overflow menus on cards.
    func symphoCardContextMenu(edit: (() -> Void)? = nil, delete: (() -> Void)? = nil) -> some View {
        contextMenu {
            if let edit {
                Button("Edit", systemImage: "pencil", action: edit)
            }
            if let delete {
                Button("Delete", role: .destructive, action: delete)
            }
        }
    }
}

struct SymphoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 7)
            .padding(.horizontal, 11)
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .fill(SymphoTheme.primaryAction)
            }
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

struct SymphoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SymphoTheme.primaryText)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .fill(SymphoTheme.elevatedCanvas.opacity(configuration.isPressed ? 0.44 : 0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .stroke(SymphoTheme.dividerColor, lineWidth: 1)
            }
    }
}

struct SymphoIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(SymphoTheme.secondaryText)
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: SymphoTheme.controlRadius, style: .continuous)
                    .fill(configuration.isPressed ? SymphoTheme.elevatedCanvas.opacity(0.78) : .clear)
            }
    }
}

struct MinimalDivider: View {
    var body: some View {
        Rectangle()
            .fill(SymphoTheme.dividerColor)
            .frame(height: 1)
    }
}

// MARK: - Hex Color

extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }

        var rgb: UInt64 = 0
        guard Scanner(string: cleanHex).scanHexInt64(&rgb) else { return nil }

        let r, g, b: Double
        if cleanHex.count == 6 {
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b)
        } else {
            return nil
        }
    }
}
