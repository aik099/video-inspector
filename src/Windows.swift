import Combine
import SwiftUI

// Windows are created here, AppKit-style (NSWindow hosting SwiftUI content), not by a SwiftUI
// WindowGroup: a tab can then be attached to its window before it's ever shown, like Finder does
final class Windows: NSObject, NSWindowDelegate {
	static let shared = Windows()
	private static let appTitle = "Video Inspector"
	private static let contentSize = ContentView.idealSize
	// Remembers the position/size of the first window across launches
	private static let frameName = "VideoInspectorWindow"

	private struct Entry {
		let window: NSWindow
		let inspector: Inspector
		var minWidthUpdates: AnyCancellable?
	}

	// Minimum content size per window, enforced in windowWillResize: AppKit resets contentMinSize
	// for SwiftUI-hosted content. Width follows the report's tab picker
	private var minContentWidth: [ObjectIdentifier: CGFloat] = [:]
	private static let minContentHeight = ContentView.minHeight

	private var entries: [Entry] = []

	private override init() {
		super.init()
		NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
			// Also fires after tabs are merged, moved or split by the user
			self.updateTitles()
		}
	}

	private var front: Entry? {
		entries.first { $0.window === NSApp.keyWindow } ?? entries.first { $0.window.isVisible }
	}

	private enum Placement {
		case restored  // first window: last saved frame
		case tab(of: NSWindow)
		case cascade(from: NSWindow)
	}

	@discardableResult
	private func makeWindow(_ placement: Placement) -> Inspector {
		let inspector = Inspector()
		let content = NSHostingView(rootView: ContentView(inspector: inspector))
		// No automatic sizing: a hosting controller (or these options) would overwrite the window's
		// minimum set below with SwiftUI's content-only minimum
		content.sizingOptions = []

		let window = NSWindow(
			contentRect: NSRect(origin: .zero, size: Self.contentSize),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered, defer: false
		)
		window.contentView = content
		window.isReleasedWhenClosed = false
		window.tabbingIdentifier = "inspector"
		window.delegate = self
		window.setContentSize(Self.contentSize)
		let minWidthUpdates = inspector.$tabBarWidth.sink { [weak self, weak window] width in
			guard let self, let window else { return }
			let minWidth = max(ContentView.minWidth, width + 40)
			self.minContentWidth[ObjectIdentifier(window)] = minWidth
			// Grow now if a new file's tabs don't fit
			let content = window.contentLayoutRect.size
			if content.width < minWidth {
				window.setContentSize(NSSize(width: minWidth, height: content.height))
			}
		}
		entries.append(Entry(window: window, inspector: inspector, minWidthUpdates: minWidthUpdates))

		switch placement {
		case .restored:
			window.center()
			window.setFrameAutosaveName(Self.frameName)
			// A frame saved before the current minimum existed is restored as is: grow it, keeping the top edge
			var frame = window.frame
			let minHeight = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 0, height: Self.minContentHeight)).height
			if frame.height < minHeight {
				frame.origin.y -= minHeight - frame.height
				frame.size.height = minHeight
				window.setFrame(frame, display: false)
			}
		case .tab(let host):
			// Attached before it's shown: appears directly as a tab
			host.addTabbedWindow(window, ordered: .above)
		case .cascade(let front):
			var frame = front.frame
			frame.origin.x += 24
			frame.origin.y -= 24
			window.setFrame(frame, display: false)
		}
		window.makeKeyAndOrderFront(nil)
		updateTitles()
		Log.debug("window \(window.windowNumber) \(placement): \(window.tabbedWindows?.count ?? 1) tab(s), frame \(window.frame.size)")

		return inspector
	}

	// Launch without files: one empty window
	func ensureWindow() {
		if entries.isEmpty { makeWindow(.restored) }
	}

	// ⌘N
	func newWindow() {
		if let front { makeWindow(.cascade(from: front.window)) } else { makeWindow(.restored) }
	}

	// ⌘T and the tab bar's "+"
	func newTab() {
		if let front { makeWindow(.tab(of: front.window)) } else { makeWindow(.restored) }
	}

	// Dock drop / "Open With" / ⌘O: first file fills the front window if it's empty, the rest get tabs
	func open(_ urls: [URL]) {
		Log.debug("open \(urls.map(\.lastPathComponent))")
		guard Shell.find("ffprobe") != nil else {
			NSSound.beep()
			// Launched by a file drop: still show the error screen
			ensureWindow()
			return
		}
		var queue = urls.filter(\.isVideoFile)
		if queue.count < urls.count { NSSound.beep() }
		guard !queue.isEmpty else {
			ensureWindow()
			return
		}
		let host: Entry
		if let front, front.inspector.url == nil, !front.inspector.isBusy {
			host = front
		} else if let front {
			host = Entry(window: front.window, inspector: makeWindow(.tab(of: front.window)))
		} else {
			let inspector = makeWindow(.restored)
			host = entries.first { $0.inspector === inspector }!
		}
		host.inspector.load(queue.removeFirst())
		openTabs(queue, next: host.window)
	}

	// Window drop: first video replaces this tab's file, the rest get tabs
	func drop(_ urls: [URL], onto inspector: Inspector) {
		Log.debug("drop \(urls.map(\.lastPathComponent))")
		guard Shell.find("ffprobe") != nil else {
			NSSound.beep()
			return
		}
		var queue = urls.filter(\.isVideoFile)
		if queue.count < urls.count { NSSound.beep() }
		guard !queue.isEmpty, let entry = entries.first(where: { $0.inspector === inspector }) else { return }
		inspector.load(queue.removeFirst())
		openTabs(queue, next: entry.window)
	}

	private func openTabs(_ urls: [URL], next window: NSWindow) {
		for url in urls {
			makeWindow(.tab(of: window)).load(url)
		}
	}

	// File › Open… (⌘O): into the front window, or a new one when none is open
	func showOpenPanel() {
		guard Shell.find("ffprobe") != nil else {
			NSSound.beep()
			return
		}
		if let front {
			front.inspector.showOpenPanel()
			return
		}
		let panel = NSOpenPanel()
		panel.allowedContentTypes = VideoTypes.contentTypes
		if panel.runModal() == .OK, let url = panel.url {
			open([url])
		}
	}

	// Alone: app name; tabbed: file name, so tabs are distinguishable
	func updateTitles() {
		for entry in entries {
			let tabbed = (entry.window.tabbedWindows?.count ?? 0) > 1
			// Empty tabs match the start screen's title
			entry.window.title = tabbed ? (entry.inspector.url?.lastPathComponent ?? "No Video File") : Self.appTitle
		}
	}

	func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
		let content = window.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize)).size
		let minWidth = minContentWidth[ObjectIdentifier(window)] ?? ContentView.minWidth
		var size = frameSize
		if content.width < minWidth { size.width += minWidth - content.width }
		if content.height < Self.minContentHeight { size.height += Self.minContentHeight - content.height }
		return size
	}

	func windowWillClose(_ notification: Notification) {
		guard let window = notification.object as? NSWindow else { return }
		entries.removeAll { $0.window === window }
		minContentWidth[ObjectIdentifier(window)] = nil
		// After AppKit has removed the closed tab from its group
		DispatchQueue.main.async { self.updateTitles() }
	}
}
