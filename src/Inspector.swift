import AppKit


// ObservableObject instead of @State: Command Line Tools lack the SwiftUI macro plugin
final class Inspector: ObservableObject {
	@Published private(set) var rows: [Row] = []
	@Published private(set) var thumbnail: NSImage?
	@Published private(set) var covers: [Int: NSImage] = [:]
	@Published private(set) var isBusy = false
	@Published var isDropTargeted = false
	@Published var isTitleHovered = false
	// Measured tab bar width; drives the window's minimum width
	@Published var tabBarWidth: CGFloat = 0
	private(set) var url: URL?

	func load(_ url: URL) {
		// No ffprobe: nothing can be read, so the error screen stays
		guard Shell.find("ffprobe") != nil else {
			Log.debug("rejected \(url.lastPathComponent): ffprobe missing")
			NSSound.beep()
			return
		}
		guard url.isVideoFile else {
			Log.debug("rejected non-video \(url.lastPathComponent)")
			NSSound.beep()
			return
		}
		self.url = url
		isBusy = true

		DispatchQueue.global().async {
			let rows = Probe.inspect(url)
			let thumbnail = Probe.thumbnail(url)
			var covers: [Int: NSImage] = [:]
			for row in rows {
				if case .section(.cover) = row.kind, let stream = row.stream {
					covers[stream] = Probe.coverImage(url, stream: stream)
				}
			}
			DispatchQueue.main.async {
				self.rows = rows
				self.thumbnail = thumbnail
				self.covers = covers
				self.isBusy = false
				Windows.shared.updateTitles()
			}
		}
	}

	func reload() {
		if let url { load(url) }
	}

	func clear() {
		url = nil
		rows = []
		thumbnail = nil
		covers = [:]
		tabBarWidth = 0
		Windows.shared.updateTitles()
	}

	func showOpenPanel() {
		guard Shell.find("ffprobe") != nil else {
			NSSound.beep()
			return
		}
		let panel = NSOpenPanel()
		panel.allowedContentTypes = VideoTypes.contentTypes
		if panel.runModal() == .OK, let url = panel.url {
			load(url)
		}
	}

	func revealInFinder() {
		if let url {
			NSWorkspace.shared.activateFileViewerSelecting([url])
		}
	}
}
