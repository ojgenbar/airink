import SwiftUI

struct EditorToolbar: View {
    @Bindable var document: AnnotationDocument
    let onCancel: () -> Void
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker("Tool", selection: $document.tool) {
                ForEach(Tool.allCases, id: \.self) { tool in
                    Label(tool.title, systemImage: tool.symbolName)
                        .help("\(tool.title) (\(tool.shortcut))")
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.iconOnly)
            .fixedSize()

            ColorSwatches(selection: $document.color)

            Picker("Width", selection: $document.width) {
                ForEach(StrokeWidth.allCases, id: \.self) { width in
                    Image(systemName: "circle.fill")
                        .imageScale(width.symbolScale)
                        .accessibilityLabel(width.title)
                        .help("\(width.title) (\(width.rawValue))")
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer(minLength: 8)

            Button("Cancel", action: onCancel)
                .help("Close without copying (Esc)")
            Button("Copy", action: onCopy)
                .buttonStyle(.borderedProminent)
                .help("Copy to clipboard and close (Return or ⌘C)")
        }
        .labelsHidden()
        .controlSize(.regular)
        .focusEffectDisabled()
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ColorSwatches: View {
    @Binding var selection: AnnotationColor

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AnnotationColor.allCases, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(Color(cgColor: color.cgColor))
                        .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 0.5))
                        .frame(width: 16, height: 16)
                        .padding(3)
                        .background {
                            if selection == color {
                                Circle().strokeBorder(.tint, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.title)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
    }
}

// MARK: - Presentation

private extension Tool {
    var title: String {
        switch self {
        case .arrow: String(localized: "Arrow")
        case .rectangle: String(localized: "Rectangle")
        case .line: String(localized: "Line")
        case .text: String(localized: "Text")
        }
    }

    var symbolName: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .line: "line.diagonal"
        case .text: "textformat"
        }
    }

    var shortcut: String {
        switch self {
        case .arrow: "A"
        case .rectangle: "R"
        case .line: "L"
        case .text: "T"
        }
    }
}

private extension StrokeWidth {
    var title: String {
        switch self {
        case .thin: String(localized: "Thin")
        case .medium: String(localized: "Medium")
        case .thick: String(localized: "Thick")
        }
    }

    var symbolScale: Image.Scale {
        switch self {
        case .thin: .small
        case .medium: .medium
        case .thick: .large
        }
    }
}

private extension AnnotationColor {
    var title: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        case .black: String(localized: "Black")
        case .white: String(localized: "White")
        }
    }
}
