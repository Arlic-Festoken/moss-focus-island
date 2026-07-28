import SwiftUI

struct TimelineFilterMenu<Content: View>: View {
    let title: String
    let accessibilityLabel: String
    let isActive: Bool
    let width: CGFloat
    private let content: Content

    @State private var isHovered = false

    init(
        title: String,
        accessibilityLabel: String,
        isActive: Bool,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.isActive = isActive
        self.width = width
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                TimelineDownChevron()
                    .foregroundStyle(isActive ? MossTheme.sage : .secondary)
            }
            .font(MossTypography.font(12, weight: .semibold))
            .foregroundStyle(isActive ? MossTheme.sage : Color.primary.opacity(0.84))
            .padding(.horizontal, 11)
            .frame(width: width, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        if isActive {
            return MossTheme.sage.opacity(isHovered ? 0.16 : 0.11)
        }
        return Color.primary.opacity(isHovered ? 0.075 : 0.045)
    }

    private var borderColor: Color {
        isActive ? MossTheme.sage.opacity(0.28) : MossTheme.hairline.opacity(isHovered ? 1.3 : 0.8)
    }
}

private struct TimelineDownChevron: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0.5, y: 0.75))
            path.addLine(to: CGPoint(x: 4, y: 4.25))
            path.addLine(to: CGPoint(x: 7.5, y: 0.75))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
        .frame(width: 8, height: 5)
    }
}

struct TimelineDateSelector: View {
    @Binding var selection: Date

    @State private var isPresented = false
    @State private var isHovered = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MossTheme.sage)
                Text(selection, format: .dateTime.year().month().day())
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(MossTypography.font(12, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.86))
            .padding(.horizontal, 11)
            .frame(height: 34)
        }
        .buttonStyle(TimelineDateButtonStyle(isHovered: isHovered, isPresented: isPresented))
        .onHover { isHovered = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            DatePicker("选择日期", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(12)
                .onChange(of: selection) {
                    isPresented = false
                }
        }
        .help("选择日期")
        .accessibilityLabel("选择日期，当前为 \(selection.formatted(.dateTime.year().month().day()))")
    }
}

struct TimelineNavigationButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(TimelineNavigationButtonStyle(isHovered: isHovered))
        .onHover { isHovered = $0 }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct TimelineDateButtonStyle: ButtonStyle {
    let isHovered: Bool
    let isPresented: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isPresented ? MossTheme.sage.opacity(0.32) : MossTheme.hairline.opacity(isHovered ? 1.3 : 0.8),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPresented {
            return MossTheme.sage.opacity(0.12)
        }
        return Color.primary.opacity(isPressed ? 0.10 : (isHovered ? 0.075 : 0.045))
    }
}

private struct TimelineNavigationButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered ? MossTheme.sage : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? MossTheme.sage.opacity(0.16)
                            : Color.primary.opacity(isHovered ? 0.075 : 0.035)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isHovered ? MossTheme.sage.opacity(0.22) : MossTheme.hairline.opacity(0.7),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
