import SwiftUI

// Windows are created here, AppKit-style (NSWindow hosting SwiftUI content), not by a SwiftUI
// WindowGroup: a tab can then be attached to its window before it's ever shown, like Finder does
final class Windows: NSObject, NSWindowDelegate {
	static let shared = Windows()
	private static let appTitle = "Video Inspector"
	private static let contentSize = NSSize(width: 540, height: 640)
	// Remembers the position/size of the first window across launches
	private static let frameName = "VideoInspectorWindow"

	private struct Entry {
		let window: NSWindow
		let inspector: Inspector
	}

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
		let controller = NSHostingController(rootView: ContentView(inspector: inspector))
		// Window keeps its own size; SwiftUI content only sets the minimum (tab bar width, start screen)
		controller.sizingOptions = [.minSize]

		let window = NSWindow(contentViewController: controller)
		window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
		window.isReleasedWhenClosed = false
		window.tabbingIdentifier = "inspector"
		window.delegate = self
		window.setContentSize(Self.contentSize)
		entries.append(Entry(window: window, inspector: inspector))

		switch placement {
		case .restored:
			window.center()
			window.setFrameAutosaveName(Self.frameName)
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
		Log.debug("window \(window.windowNumber) \(placement): \(window.tabbedWindows?.count ?? 1) tab(s)")
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

	func windowWillClose(_ notification: Notification) {
		guard let window = notification.object as? NSWindow else { return }
		entries.removeAll { $0.window === window }
		// After AppKit has removed the closed tab from its group
		DispatchQueue.main.async { self.updateTitles() }
	}
}
