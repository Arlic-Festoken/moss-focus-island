import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0
    @State private var completion: CompletionState = .completed
    @State private var blocker: BlockerType = .none
    @State private var distraction: DistractionSource = .none
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("这段怎么样？")
                        .font(MossTypography.font(25, weight: .bold))
                    Text(store.currentTaskTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(step + 1) / 3")
                    .font(.caption.bold())
                    .foregroundStyle(MossTheme.sage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MossTheme.sage.opacity(0.1), in: Capsule())
            }

            Group {
                switch step {
                case 0: choiceGrid(CompletionState.allCases, selection: $completion)
                case 1:
                    VStack(alignment: .leading, spacing: 15) {
                        Text("有卡住吗？")
                            .font(.headline)
                        choiceGrid(BlockerType.allCases, selection: $blocker)
                        if blocker == .unknown || blocker == .difficult {
                            TextField("卡在：可选，写一句就够", text: $note)
                                .textFieldStyle(.roundedBorder)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                default:
                    VStack(alignment: .leading, spacing: 15) {
                        Text("分心来源？")
                            .font(.headline)
                        choiceGrid(DistractionSource.allCases, selection: $distraction)
                    }
                }
            }
            .frame(minHeight: 120, alignment: .topLeading)

            HStack {
                Button(step == 0 ? "继续专注" : "上一步") {
                    if step == 0 {
                        store.cancelReview()
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
                    }
                }
                .buttonStyle(MossJellyPlainButtonStyle())
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(step == 2 ? "记录这一段" : "下一步") {
                    if step == 2 {
                        store.finishReview(
                            completion: completion,
                            blocker: blocker,
                            distraction: distraction,
                            note: note
                        )
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
                    }
                }
                .buttonStyle(CapsuleButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
        .background(MossTheme.paper)
        .interactiveDismissDisabled()
    }

    private func choiceGrid<T: Hashable & CaseIterable>(
        _ values: T.AllCases,
        selection: Binding<T>
    ) -> some View where T.AllCases: RandomAccessCollection {
        HStack(spacing: 10) {
            ForEach(Array(values), id: \.self) { value in
                Button {
                    selection.wrappedValue = value
                } label: {
                    Text(label(for: value))
                        .font(MossTypography.font(13, weight: .semibold))
                        .foregroundStyle(selection.wrappedValue == value ? MossTheme.current.accentForeground : MossTheme.sageDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(selection.wrappedValue == value ? MossTheme.sage : MossTheme.sage.opacity(0.09))
                        )
                }
                .buttonStyle(MossJellyPlainButtonStyle())
            }
        }
    }

    private func label<T>(for value: T) -> String {
        if let value = value as? CompletionState { return value.title }
        if let value = value as? BlockerType { return value.title }
        if let value = value as? DistractionSource { return value.title }
        return String(describing: value)
    }
}
