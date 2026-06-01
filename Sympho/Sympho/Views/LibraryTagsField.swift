//
//  LibraryTagsField.swift
//  Sympho
//

import SwiftUI
import SwiftData

enum LibraryTagsHelper {
    static func normalizedName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func findOrCreateTag(named raw: String, in context: ModelContext, cache: inout [LibraryTag]) -> LibraryTag? {
        let name = normalizedName(raw)
        guard !name.isEmpty else { return nil }

        if let existing = cache.first(where: { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }) {
            return existing
        }

        let tag = LibraryTag(name: name)
        context.insert(tag)
        cache.append(tag)
        return tag
    }

    static func parseTagNames(from raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { normalizedName(String($0)) }
            .filter { !$0.isEmpty }
    }

    static func applyTags(
        names: [String],
        to resource: Resource,
        in context: ModelContext,
        allTags: inout [LibraryTag]
    ) {
        resource.tags.removeAll()
        for name in names {
            if let tag = findOrCreateTag(named: name, in: context, cache: &allTags) {
                if !resource.tags.contains(where: { $0.id == tag.id }) {
                    resource.tags.append(tag)
                }
            }
        }
    }

    static func applyTags(
        names: [String],
        to item: ReadingListItem,
        in context: ModelContext,
        allTags: inout [LibraryTag]
    ) {
        item.tags.removeAll()
        for name in names {
            if let tag = findOrCreateTag(named: name, in: context, cache: &allTags) {
                if !item.tags.contains(where: { $0.id == tag.id }) {
                    item.tags.append(tag)
                }
            }
        }
    }
}

struct LibraryTagsField: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LibraryTag.name) private var allTags: [LibraryTag]

    @Binding var selectedTags: [LibraryTag]
    @State private var draftTagText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selectedTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(selectedTags) { tag in
                        tagChip(tag, isSelected: true) {
                            selectedTags.removeAll { $0.id == tag.id }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SymphoTheme.secondaryText)

                TextField("Add tags (optional)", text: $draftTagText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit(commitDraft)

                if !draftTagText.isEmpty {
                    Button("Add", action: commitDraft)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .librarySurface()

            if !suggestedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestedTags) { tag in
                            tagChip(tag, isSelected: false) {
                                if !selectedTags.contains(where: { $0.id == tag.id }) {
                                    selectedTags.append(tag)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var suggestedTags: [LibraryTag] {
        allTags.filter { tag in
            !selectedTags.contains(where: { $0.id == tag.id })
        }
        .prefix(12)
        .map { $0 }
    }

    private func tagChip(_ tag: LibraryTag, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag.name)
                    .font(.system(size: 10, weight: .medium))
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? SymphoTheme.primaryCanvas : SymphoTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(isSelected ? SymphoTheme.primaryText : SymphoTheme.elevatedCanvas.opacity(0.7))
            }
            .overlay {
                Capsule()
                    .stroke(SymphoTheme.dividerColor, lineWidth: isSelected ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func commitDraft() {
        var cache = allTags
        let names = LibraryTagsHelper.parseTagNames(from: draftTagText)
        guard !names.isEmpty else { return }

        for name in names {
            if let tag = LibraryTagsHelper.findOrCreateTag(named: name, in: modelContext, cache: &cache),
               !selectedTags.contains(where: { $0.id == tag.id }) {
                selectedTags.append(tag)
            }
        }
        draftTagText = ""
        try? modelContext.save()
    }
}

/// Simple wrapping layout for tag chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

private extension View {
    func librarySurface() -> some View {
        background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SymphoTheme.elevatedCanvas.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SymphoTheme.dividerColor, lineWidth: 1)
        }
    }
}
