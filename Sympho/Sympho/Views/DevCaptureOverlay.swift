//
//  DevCaptureOverlay.swift
//  Sympho
//

import SwiftUI
import SwiftData

struct DevCaptureOverlay: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNavigationContext.self) private var navigationContext

    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var bodyText = ""
    @State private var kind: DevCaptureKind = .improvement
    @State private var assignee: DevCaptureAssignee = .cursor
    @State private var saveErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Developer Capture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SymphoTheme.primaryText)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Captured here")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                Text(navigationContext.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(SymphoTheme.secondaryText)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                Picker("Type", selection: $kind) {
                    ForEach(DevCaptureKind.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Assign to")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SymphoTheme.tertiaryText)

                Picker("Assignee", selection: $assignee) {
                    ForEach(DevCaptureAssignee.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 8))

            TextEditor(text: $bodyText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(8)
                .background(SymphoTheme.elevatedCanvas.opacity(0.55), in: .rect(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("What happened, what should change, steps to reproduce…")
                            .font(.system(size: 13))
                            .foregroundStyle(SymphoTheme.tertiaryText)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Spacer()

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(SymphoTheme.colorCritical)
                }

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SymphoSecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveCapture()
                }
                .buttonStyle(SymphoPrimaryButtonStyle())
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .background(SymphoTheme.primaryCanvas)
        #if os(macOS)
        .frame(width: 520, height: 520)
        #endif
        .onAppear {
            applySuggestedDefaults()
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applySuggestedDefaults() {
        if navigationContext.moduleTitle != nil {
            kind = .moduleIdea
        } else if navigationContext.nodeTitle != nil {
            kind = .improvement
        }

        assignee = .cursor
    }

    private func saveCapture() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let capture = DevCapture(
            title: trimmedTitle,
            bodyText: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            assignee: assignee,
            contextSummary: navigationContext.summary,
            contextSection: navigationContext.sectionTitle,
            contextDomainTitle: navigationContext.domainTitle,
            contextTrackTitle: navigationContext.trackTitle,
            contextModuleTitle: navigationContext.moduleTitle,
            contextNodeTitle: navigationContext.nodeTitle,
            contextProjectTitle: navigationContext.projectTitle
        )

        modelContext.insert(capture)

        do {
            try modelContext.save()
            saveErrorMessage = nil
            isPresented = false
            dismiss()
        } catch {
            saveErrorMessage = "Could not save capture."
            print("Dev capture save failed: \(error.localizedDescription)")
        }
    }
}
