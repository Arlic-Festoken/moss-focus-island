import CoreGraphics
import Foundation

@main
struct MossCompanionBehaviorCheck {
    static func main() {
        let expectedPoses: [(FocusPhase, CompanionPose)] = [
            (.idle, .waiting),
            (.preparing, .waking),
            (.focusing, .focusing),
            (.paused, .concerned),
            (.breakTime, .resting),
            (.awaitingReview, .reflecting)
        ]

        for (phase, expectedPose) in expectedPoses {
            let presentation = CompanionPresentation.make(
                phase: phase,
                theme: .moss,
                interactionIndex: 0,
                taskTitle: "整理桌宠交互",
                todayCompletedCount: 0
            )
            precondition(presentation.pose == expectedPose)
            precondition(!presentation.status.isEmpty)
            precondition(!presentation.symbol.isEmpty)
            precondition(!presentation.dialogue.isEmpty)
        }

        let completedIdle = CompanionPresentation.make(
            phase: .idle,
            theme: .moss,
            interactionIndex: 2,
            taskTitle: "",
            todayCompletedCount: 3
        )
        precondition(completedIdle.pose == .celebrating)
        precondition(completedIdle.status.contains("3"))

        let firstMossLine = CompanionPresentation.make(
            phase: .idle,
            theme: .moss,
            interactionIndex: 0,
            taskTitle: "",
            todayCompletedCount: 0
        ).dialogue
        let wrappedMossLine = CompanionPresentation.make(
            phase: .idle,
            theme: .moss,
            interactionIndex: 4,
            taskTitle: "",
            todayCompletedCount: 0
        ).dialogue
        precondition(firstMossLine == wrappedMossLine)

        let sizes = CompanionSize.allCases.map(\.panelSize)
        precondition(sizes.count == 3)
        precondition(sizes[0].width < sizes[1].width)
        precondition(sizes[1].width < sizes[2].width)
        precondition(sizes[0].height < sizes[1].height)
        precondition(sizes[1].height < sizes[2].height)

        let visibleFrame = CGRect(x: 100, y: 50, width: 1_200, height: 760)
        let defaultFrame = CompanionPanelGeometry.defaultFrame(
            size: CompanionSize.regular.panelSize,
            in: visibleFrame
        )
        precondition(defaultFrame.maxX == visibleFrame.maxX - 26)
        precondition(defaultFrame.minY == visibleFrame.minY + 34)

        let offscreenFrame = CGRect(
            x: -8_000,
            y: 9_000,
            width: CompanionSize.generous.panelSize.width,
            height: CompanionSize.generous.panelSize.height
        )
        let clamped = CompanionPanelGeometry.clamped(offscreenFrame, to: visibleFrame)
        precondition(clamped.minX == visibleFrame.minX + 8)
        precondition(clamped.maxY == visibleFrame.maxY - 8)

        precondition(CompanionMotionMode.allCases.count == 2)
        precondition(CompanionWindowLayer.allCases.count == 2)
        print("desktop-companion-behavior=pass")
    }
}
