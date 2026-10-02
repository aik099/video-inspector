import SwiftUI

// Drop a video file to see its ffprobe info and a thumbnail (iSedora Inspector style)
@main
struct VideoInspectorApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

	var body: some Scene {
		// Windows are made by `Windows` (AppKit); this scene only carries the menu commands
		Settings { EmptyView() }
			.commands {
				CommandGroup(replacing: .appSettings) {}
				CommandGroup(replacing: .newItem) {
					Button("New Window") { Windows.shared.newWindow() }
						.keyboardShortcut("n")
					Button("New Tab") { Windows.shared.newTab() }
						.keyboardShortcut("t")
					Button("Open…") { Windows.shared.showOpenPanel() }
						.keyboardShortcut("o")
				}
			}
	}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationWillFinishLaunching(_ notification: Notification) {
		NSWindow.allowsAutomaticWindowTabbing = true
	}

	// Launched with files: `application(_:open:)` has already made the window
	func applicationDidFinishLaunching(_ notification: Notification) {
		Windows.shared.ensureWindow()
	}

	// Files dropped on the Dock icon or opened via "Open With"
	func application(_ application: NSApplication, open urls: [URL]) {
		Windows.shared.open(urls)
	}

	// Tab bar "+"
	@objc func newWindowForTab(_ sender: Any?) {
		Windows.shared.newTab()
	}

	// Dock icon clicked with no window open
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
		if !hasVisibleWindows { Windows.shared.ensureWindow() }
		return true
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
		true
	}
}
