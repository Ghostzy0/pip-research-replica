import AppKit
import XCTest
@testable import ResearchDesktop

@MainActor
final class NotesSheetTerminationPolicyTests: XCTestCase {
    func testTrackingViewMovesPolicyBetweenWindowsAndRestoresEachOne() {
        let firstWindow = makeWindow(preventsTermination: true)
        let secondWindow = makeWindow(preventsTermination: true)
        let unrelatedWindow = makeWindow(preventsTermination: false)
        let coordinator = NotesTerminationWindowPolicyCoordinator()
        let trackingView = NotesTerminationWindowTrackingView(frame: .zero)
        trackingView.isHidden = true
        trackingView.coordinator = coordinator

        firstWindow.contentView?.addSubview(trackingView)
        XCTAssertTrue(trackingView.window === firstWindow)
        XCTAssertFalse(firstWindow.preventsApplicationTerminationWhenModal)
        XCTAssertTrue(secondWindow.preventsApplicationTerminationWhenModal)
        XCTAssertFalse(unrelatedWindow.preventsApplicationTerminationWhenModal)

        // Reassert policy without replacing the original value captured for restoration.
        firstWindow.preventsApplicationTerminationWhenModal = true
        coordinator.attach(to: firstWindow)
        XCTAssertFalse(firstWindow.preventsApplicationTerminationWhenModal)
        coordinator.attach(to: firstWindow)
        XCTAssertFalse(firstWindow.preventsApplicationTerminationWhenModal)

        trackingView.removeFromSuperview()
        XCTAssertTrue(firstWindow.preventsApplicationTerminationWhenModal)

        secondWindow.contentView?.addSubview(trackingView)
        XCTAssertTrue(trackingView.window === secondWindow)
        XCTAssertFalse(secondWindow.preventsApplicationTerminationWhenModal)
        XCTAssertFalse(unrelatedWindow.preventsApplicationTerminationWhenModal)

        coordinator.detach()
        XCTAssertTrue(secondWindow.preventsApplicationTerminationWhenModal)
        trackingView.removeFromSuperview()
        XCTAssertFalse(unrelatedWindow.preventsApplicationTerminationWhenModal)
    }

    func testDetachRestoresAnOriginallyPermissiveWindowAndIsIdempotent() {
        let window = makeWindow(preventsTermination: false)
        let coordinator = NotesTerminationWindowPolicyCoordinator()

        coordinator.attach(to: window)
        XCTAssertFalse(window.preventsApplicationTerminationWhenModal)

        coordinator.detach()
        XCTAssertFalse(window.preventsApplicationTerminationWhenModal)
        coordinator.detach()
        XCTAssertFalse(window.preventsApplicationTerminationWhenModal)
    }

    private func makeWindow(preventsTermination: Bool) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        window.preventsApplicationTerminationWhenModal = preventsTermination
        return window
    }
}
