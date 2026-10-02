import SwiftUI

// One inspector per window; windows group as macOS tabs
struct WindowHost: View {
	@StateObject private var inspector = Inspector()
	@Environment(\.openWindow) private var openWindow

	var body: some View {
		ContentView(inspector: inspector)
			.background(WindowAccessor { Windows.shared.register($0, inspector) })
			.onAppear { Windows.shared.openWindow = openWindow }
	}
}

// Hands back the NSWindow hosting a SwiftUI view, once the view is attached to it
private struct WindowAccessor: NSViewRepresentable {
	let onWindow: (NSWindow) -> Void

	func makeNSView(context: Context) -> NSView {
		WindowReportingView(onWindow: onWindow)
	}

	func updateNSView(_ view: NSView, context: Context) {}
}

private final class WindowReportingView: NSView {
	private let onWindow: (NSWindow) -> Void

	init(onWindow: @escaping (NSWindow) -> Void) {
		self.onWindow = onWindow
		super.init(frame: .zero)
	}

	required init?(coder: NSCoder) { nil }

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		// Async: let SwiftUI finish showing the window before tabbing it
		if let window { DispatchQueue.main.async { self.onWindow(window) } }
	}
}

// Tracks windows, routes incoming files, keeps tab titles current
final class Windows {
	static let shared = Windows()
	static let sceneID = "inspector"
	private static let appTitle = "Video Inspector"

	private struct Entry {
		weak var window: NSWindow?
		let inspector: Inspector
	}

	var openWindow: OpenWindowAction?
	private var entries: [Entry] = []
	// Files waiting for a new tab to appear
	private var pending: [URL] = []
	// A window was requested but hasn't registered yet
	private var isOpeningWindow = false
	// Windows requested as tabs (⌘T, extra files); ⌘N windows stay separate
	private var tabRequests = 0

	private init() {
		for name in [NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification] {
			NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
				// After close/merge settles
				DispatchQueue.main.async { self.updateTitles() }
			}
		}
	}

	func register(_ window: NSWindow, _ inspector: Inspector) {
		Log.debug("register window \(window.windowNumber): pending=\(pending.count) tabRequests=\(tabRequests)")
		entries.removeAll { $0.window == nil || $0.window === window }
		entries.append(Entry(window: window, inspector: inspector))
		isOpeningWindow = false

		let others = entries.compactMap(\.window).filter { $0 !== window && $0.isVisible }
		if tabRequests == 0, let front = others.first(where: \.isKeyWindow) ?? others.last {
			// Separate window (⌘N): front window's size, cascaded like Finder/Safari
			var frame = front.frame
			frame.origin.x += 24
			frame.origin.y -= 24
			window.setFrame(frame, display: true)
		}

		// Requested as a tab: join an existing window (AppKit doesn't tab already-shown windows)
		if tabRequests > 0 {
			tabRequests -= 1
			if window.tabbedWindows == nil,
				let host = entries.compactMap(\.window).first(where: { $0 !== window && $0.isVisible })
			{
				host.addTabbedWindow(window, ordered: .above)
				window.makeKeyAndOrderFront(nil)
			}
		}
		loadPending(into: inspector)
		updateTitles()
	}

	private func loadPending(into inspector: Inspector) {
		guard !pending.isEmpty else { return }
		inspector.load(pending.removeFirst())
		if !pending.isEmpty { newTab() }
	}

	// Dock drop / "Open With": first file fills the front window if it's empty, the rest get new tabs
	func open(_ urls: [URL]) {
		guard Shell.find("ffprobe") != nil else {
			NSSound.beep()
			// Launched by a file drop: still show the error screen
			ensureWindow()
			return
		}
		Log.debug("open \(urls.map(\.lastPathComponent))")
		var queue = urls.filter(\.isVideoFile)
		if queue.count < urls.count { NSSound.beep() }
		let front = entries.first { $0.window === NSApp.keyWindow } ?? entries.first { $0.window != nil }
		if let front, front.inspector.url == nil, !front.inspector.isBusy, !queue.isEmpty {
			front.inspector.load(queue.removeFirst())
		}
		guard !queue.isEmpty else { return }
		pending += queue
		// No window yet: the first one picks up pending files when it registers
		if !entries.contains(where: { $0.window != nil }) {
			ensureWindow()
			return
		}
		newTab()
	}

	// Window drop: first video replaces this tab's file, the rest get new tabs
	func drop(_ urls: [URL], onto inspector: Inspector) {
		guard Shell.find("ffprobe") != nil else {
			NSSound.beep()
			return
		}
		Log.debug("drop \(urls.map(\.lastPathComponent))")
		var queue = urls.filter(\.isVideoFile)
		if queue.count < urls.count { NSSound.beep() }
		guard !queue.isEmpty else { return }
		inspector.load(queue.removeFirst())
		guard !queue.isEmpty else { return }
		pending += queue
		newTab()
	}

	func newTab() {
		// The very first window has nothing to join
		if entries.contains(where: { $0.window != nil }) { tabRequests += 1 }
		requestWindow()
	}

	// SwiftUI skips its initial window when launched to open files
	func ensureWindow() {
		// Delay lets SwiftUI's own launch window (if any) appear first
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
			let hasWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
			Log.debug("ensureWindow: hasWindow=\(hasWindow) opening=\(self.isOpeningWindow)")
			guard !hasWindow, !self.isOpeningWindow else { return }
			self.requestWindow()
		}
	}

	private func requestWindow() {
		Log.debug("requestWindow via \(openWindow != nil ? "openWindow" : "menu item")")
		isOpeningWindow = true
		if let openWindow {
			openWindow(id: Self.sceneID)
		} else if let item = Self.newWindowMenuItem(), let menu = item.menu {
			// No view has run yet to hand over openWindow: use File > New Window (⌘N)
			menu.performActionForItem(at: menu.index(of: item))
		}
	}

	private static func newWindowMenuItem() -> NSMenuItem? {
		func search(_ menu: NSMenu) -> NSMenuItem? {
			for item in menu.items {
				if item.keyEquivalent == "n", item.keyEquivalentModifierMask == .command { return item }
				if let found = item.submenu.flatMap(search) { return found }
			}
			return nil
		}
		return NSApp.mainMenu.flatMap(search)
	}

	// File › Open… (⌘O): loads into the front window, or a new one when none is open
	func showOpenPanel() {
		guard Shell.find("ffprobe") != nil else {
			NSSound.beep()
			return
		}
		if let front = entries.first(where: { $0.window === NSApp.keyWindow }) {
			front.inspector.showOpenPanel()
			return
		}
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.movie]
		if panel.runModal() == .OK, let url = panel.url {
			open([url])
		}
	}

	// Alone: app name; tabbed: file name, so tabs are distinguishable
	func updateTitles() {
		entries.removeAll { $0.window == nil }
		for entry in entries {
			guard let window = entry.window else { continue }
			let tabbed = (window.tabbedWindows?.count ?? 0) > 1
			// Empty tabs match the start screen's title
			window.title = tabbed ? (entry.inspector.url?.lastPathComponent ?? "No Video File") : Self.appTitle
		}
	}
}

