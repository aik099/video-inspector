import SwiftUI

// Drop a video file to see its ffprobe info and a thumbnail (iSedora Inspector style)
@main
struct VideoInspectorApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

	var body: some Scene {
		WindowGroup("Video Inspector", id: Windows.sceneID) {
			WindowHost()
		}
		// File opens are routed by AppDelegate, not by SwiftUI spawning windows
		.handlesExternalEvents(matching: [])
		.defaultSize(width: 540, height: 640)
		.windowResizability(.contentSize)
		.commands {
			CommandGroup(after: .newItem) {
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

	func applicationDidFinishLaunching(_ notification: Notification) {
		Windows.shared.ensureWindow()
	}

	// Files dropped on the Dock icon or opened via "Open With"
	func application(_ application: NSApplication, open urls: [URL]) {
		Windows.shared.open(urls)
	}

	// File > New Tab (⌘T) and the tab bar's "+" button
	@objc func newWindowForTab(_ sender: Any?) {
		Windows.shared.newTab()
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
		true
	}
}
