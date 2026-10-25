import SwiftUI

struct EditorToolbar: View {
    @Bindable var document: AnnotationDocument
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onCancel: () -> Void
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SegmentGroup {
                ForEach(Tool.allCases, id: \.self) { tool in
                    ShortcutSegment(
                        title: tool.title,
                        shortcut: tool.shortcut,
                        isSelected: document.tool == tool
                    ) {
                        document.tool = tool
                    } label: {
                        ToolIcon(tool: tool)
                    }
                }
            }

            ColorSwatches(selection: $document.color)
                .disabled(document.tool == .pixelate)
                .opacity(document.tool == .pixelate ? 0.4 : 1)

            SegmentGroup {
                ForEach(StrokeWidth.allCases, id: \.self) { width in
                    ShortcutSegment(
                        title: width.title,
                        shortcut: String(width.rawValue),
                        isSelected: document.width == width
                    ) {
                        document.width = width
                    } label: {
                        Circle().frame(width: width.dotDiameter, height: width.dotDiameter)
                    }
                }
            }

            Spacer(minLength: 8)

            ControlGroup {
                Button("Undo", systemImage: "arrow.uturn.backward", action: onUndo)
                    .disabled(!document.canUndo)
                    .help("Undo (⌘Z)")
                Button("Redo", systemImage: "arrow.uturn.forward", action: onRedo)
                    .disabled(!document.canRedo)
                    .help("Redo (⇧⌘Z)")
            }
            .labelStyle(.iconOnly)
            .fixedSize()

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

/// A segmented-control look-alike whose segments can show a shortcut hint.
/// (The native segmented picker can't, and it draws all icons at one size.)
private struct SegmentGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 2) {
            content
        }
        .padding(2)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }
}

private struct ShortcutSegment<Label: View>: View {
    let title: String
    let shortcut: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .frame(width: 32, height: 24)
                .overlay(alignment: .bottomTrailing) {
                    Text(shortcut)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.tertiary))
                        .padding(.trailing, 2)
                        .padding(.bottom, 1)
                }
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6).fill(.tint)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("\(title) (\(shortcut))")
        .accessibilityLabel(title)
        .accessibilityHint(String(localized: "Shortcut: \(shortcut)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ToolIcon: View {
    let tool: Tool

    var body: some View {
        switch tool {
        case .arrow: Image(systemName: "arrow.up.right")
        case .rectangle: Image(systemName: "square")
        case .line: Image(systemName: "line.diagonal")
        case .text: Text(verbatim: "T").font(.system(size: 15, weight: .semibold))
        case .pixelate: CheckerboardIcon()
        }
    }
}

/// A 2×2 checkerboard: no SF Symbol shows exactly this.
private struct CheckerboardIcon: View {
    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow { Rectangle(); Color.clear }
            GridRow { Color.clear; Rectangle() }
        }
        .frame(width: 13, height: 13)
        .clipShape(.rect(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(lineWidth: 1.25))
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
        case .pixelate: String(localized: "Pixelate")
        }
    }

    var shortcut: String {
        switch self {
        case .arrow: "A"
        case .rectangle: "R"
        case .line: "L"
        case .text: "T"
        case .pixelate: "P"
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

    var dotDiameter: CGFloat {
        switch self {
        case .thin: 4
        case .medium: 7
        case .thick: 11
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
