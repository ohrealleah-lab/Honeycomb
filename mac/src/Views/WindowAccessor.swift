import SwiftUI
import AppKit

// Window Accessor and Detecting View helpers for resizing the macOS window to match the
// board size. Shared by every game view (GameView, BeecellView, SpiderView, VideoPokerView,
// BlackjackView, HoneycombView) — all six games share one hidden-titlebar window, and each
// view's own recomputeScale()/applyInitialWindowSize() hooks into this to fit its board.
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void
    // Called every time the window resizes, for any reason (live drag, our own
    // programmatic resizes, etc.) — games use this to continuously refit their board's
    // scale to the window's current size. This view has no idea what a "board" is; it
    // just reports that a resize happened.
    var onResize: (() -> Void)? = nil

    func makeNSView(context: Context) -> WindowDetectingView {
        WindowDetectingView(onWindowDetected: callback, onResize: onResize)
    }

    func updateNSView(_ nsView: WindowDetectingView, context: Context) {
        nsView.onResize = onResize
    }
}

class WindowDetectingView: NSView {
    var onWindowDetected: (NSWindow) -> Void
    var onResize: (() -> Void)?
    private var resizeObserver: Any?

    init(onWindowDetected: @escaping (NSWindow) -> Void, onResize: (() -> Void)? = nil) {
        self.onWindowDetected = onWindowDetected
        self.onResize = onResize
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            onWindowDetected(window)
            observeResize(of: window)
        }
    }

    // Live interactive drag-resizing (grabbing an edge/corner by hand) is pure native
    // AppKit behavior — none of this app's own resize logic (recomputeScale/
    // applyInitialWindowSize) runs during it, so this notification is the only hook for
    // it. Two jobs on every resize: (1) if the window ever ends up positioned such that
    // its top edge is above the screen's visible area (stale OS window restoration, an
    // edge case in native resizing, etc.), correct it — the toolbar/title bar must stay
    // reachable; (2) let the game view recompute its fit-to-window scale.
    private func observeResize(of window: NSWindow) {
        if let existing = resizeObserver { NotificationCenter.default.removeObserver(existing) }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: window, queue: .main
        ) { [weak self, weak window] _ in
            guard let window, let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
            var frame = window.frame
            if frame.maxY > visible.maxY {
                frame.origin.y = visible.maxY - frame.height
                window.setFrame(frame, display: true)
            }
            self?.onResize?()
        }
    }

    deinit {
        if let existing = resizeObserver { NotificationCenter.default.removeObserver(existing) }
    }
}

class WindowZoomController {
    private weak var window: NSWindow?
    private var previousFrame: NSRect?
    private var eventMonitor: Any?

    init(window: NSWindow) {
        self.window = window
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let win = self.window, event.window === win, event.clickCount == 2 else { return event }
            let contentHeight = win.contentView?.frame.height ?? 0
            if event.locationInWindow.y > contentHeight {
                self.toggleZoom()
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }

    func toggleZoom() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        if let prev = previousFrame {
            window.setFrame(prev, display: true, animate: true)
            previousFrame = nil
        } else {
            previousFrame = window.frame
            window.setFrame(screen.visibleFrame, display: true, animate: true)
        }
    }

    func clearZoomState() {
        previousFrame = nil
    }
}

// Shared board-fit-to-window math, factored out of each game view's own recomputeScale().
// Every game still computes its own intrinsic board size and height inset (toolbar height,
// legend height, etc. — these genuinely differ per game), but the final clamp to a usable
// zoom range is identical everywhere, so it lives here once.
enum WindowFit {
    static func scale(contentSize: CGSize, intrinsicSize: CGSize, heightInset: CGFloat) -> CGFloat {
        let scaleX = contentSize.width / intrinsicSize.width
        let scaleY = (contentSize.height - heightInset) / intrinsicSize.height
        return min(2.0, max(0.3, min(scaleX, scaleY)))
    }
}

extension NSWindow {
    // Sets `contentMinSize` and, only on the very first launch ever (`HasLaunchedBefore`),
    // centers the window at `defaultOpeningSize`. Subsequent launches/game-switches never
    // resize the window, so manual resizing stays seamless across games. Pass nil for
    // `defaultOpeningSize` for games (like Honeycomb) that don't own the app's first-launch
    // default size.
    func applyInitialSize(minSize: NSSize, defaultOpeningSize: NSSize?) {
        contentMinSize = minSize
        guard let defaultOpeningSize, !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") else { return }
        UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        var newFrame = frameRect(forContentRect: NSRect(origin: .zero, size: defaultOpeningSize))
        if let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            newFrame.origin.x = visible.midX - newFrame.width / 2
            newFrame.origin.y = visible.midY - newFrame.height / 2
        }
        setFrame(newFrame, display: true)
    }
}
