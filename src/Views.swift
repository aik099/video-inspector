import SwiftUI

struct ContentView: View {
	// Small minimum like native apps: start screen and report both scroll when short,
	// so the tab bar can take its height from the content without the window growing
	static let minHeight: CGFloat = 360
	static let minWidth: CGFloat = 420
	// Default window content: whole start screen visible
	static let idealSize = NSSize(width: 540, height: 656)

	@ObservedObject var inspector: Inspector

	var body: some View {
		Group {
			if inspector.isBusy {
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if inspector.rows.isEmpty {
				StartView(inspector: inspector)
			} else {
				VStack(spacing: 0) {
					ReportView(inspector: inspector)
					Divider()
					BottomBar(inspector: inspector)
				}
			}
		}
		// Minimum size is enforced by the window (Windows.windowWillResize). The ideal size matters:
		// the hosting view resizes the window to it on first layout
		.frame(
			idealWidth: ContentView.idealSize.width, maxWidth: .infinity,
			idealHeight: ContentView.idealSize.height, maxHeight: .infinity
		)
		.overlay {
			if inspector.isDropTargeted {
				RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3)
			}
		}
		.onDrop(of: [.fileURL], isTargeted: $inspector.isDropTargeted) { providers in
			guard !providers.isEmpty else { return false }
			// URLs load asynchronously; collect all, keeping drop order
			var urls = [URL?](repeating: nil, count: providers.count)
			let group = DispatchGroup()
			for (index, provider) in providers.enumerated() {
				group.enter()
				_ = provider.loadObject(ofClass: URL.self) { url, _ in
					DispatchQueue.main.async {
						urls[index] = url
						group.leave()
					}
				}
			}
			group.notify(queue: .main) {
				Windows.shared.drop(urls.compactMap { $0 }, onto: inspector)
			}
			return true
		}
	}
}

struct StartView: View {
	@ObservedObject var inspector: Inspector
	private let canProbe = Shell.find("ffprobe") != nil

	var body: some View {
		// One scroll area for the whole screen: fills a tall window, scrolls in a short one
		// (squeezed, ContentUnavailableView would scroll on its own and cut the icon off)
		GeometryReader { geometry in
			ScrollView {
				content
					.frame(minHeight: geometry.size.height)
			}
		}
	}

	private var content: some View {
		VStack(spacing: 0) {
			Group {
				if canProbe {
					// System empty-state layout: icon, title, description, actions
					ContentUnavailableView {
						// Explicit icon: the plain Label form dropped it here
						emptyStateTitle("No Video File", symbol: "film.stack", tint: .secondary)
					} description: {
						Text("Press ⌘O or drag & drop a video file to this window.\nPress ⌘T to inspect another file in a new tab.")
					} actions: {
						OpenButton(inspector: inspector)
							.controlSize(.large)
					}
				} else {
					// Nothing can be opened: error replaces the open prompt
					ContentUnavailableView {
						emptyStateTitle("ffprobe Not Found", symbol: "exclamationmark.triangle", tint: .orange)
					} description: {
						VStack(spacing: 10) {
							Text("Video Inspector reads video files with ffprobe and makes thumbnails with ffmpeg. Put both programs into one of these folders:\n\n\(Shell.searchFolders)\n\nStatic builds, Homebrew and MacPorts all work. Relaunch afterwards.")
								.textSelection(.enabled)
							// Natural width: may extend past the narrow description column instead of wrapping
							DownloadLinks()
								.fixedSize()
						}
					}
				}
			}
			// Room for icon, title, two hint lines and button
			.frame(minHeight: 280)
			TVGuideView()
				.padding(.horizontal, 20)
				.padding(.bottom, 20)
		}
		.frame(maxWidth: .infinity)
	}

	private func emptyStateTitle(_ title: String, symbol: String, tint: Color) -> some View {
		VStack(spacing: 12) {
			Image(systemName: symbol)
				.font(.system(size: 48))
				.foregroundStyle(tint)
			Text(title)
		}
	}
}

// Static builds; ffmpeg and ffprobe are separate downloads there
struct DownloadLinks: View {
	var body: some View {
		// One per line: side by side they're wider than the window
		VStack(spacing: 4) {
			ForEach(Shell.downloadLinks, id: \.url) { link in
				HoverLink(title: link.title, url: link.url)
			}
		}
		// Room for the link highlight at the outer edges
		.padding(.horizontal, 4)
	}
}

private final class HoverState: ObservableObject {
	@Published var isHovered = false
}

// Link that underlines on hover, like the file-name link
struct HoverLink: View {
	let title: String
	let url: URL
	@StateObject private var hover = HoverState()

	var body: some View {
		Link(destination: url) {
			Text(title).underline(hover.isHovered)
		}
		// No initial focus ring, like the app's buttons
		.focusable(false)
		.onHover { hover.isHovered = $0 }
	}
}

// In place of the thumbnail when ffmpeg is missing; files still open via ffprobe
struct FfmpegMissingView: View {
	var body: some View {
		// Centered like the ffprobe error screen
		VStack(spacing: 6) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.title2)
				.foregroundStyle(.orange)
			Text("No thumbnail: ffmpeg not found").bold()
			Text("Thumbnails and cover-art previews need ffmpeg. Put it into one of these folders:\n\n\(Shell.searchFolders)\n\nStatic builds, Homebrew and MacPorts all work.")
				.foregroundStyle(.secondary)
				.textSelection(.enabled)
			DownloadLinks()
		}
		.multilineTextAlignment(.center)
		.font(.callout)
		.fixedSize(horizontal: false, vertical: true)
		.frame(maxWidth: .infinity)
	}
}

// How a video's aspect ratio maps onto a 16:9 screen
struct TVGuideView: View {
	private let bands: [(ratio: String, result: String)] = [
		("1.78 (16:9)", "Fills the whole screen"),
		("1.85 – 2.0", "Thin bars top and bottom"),
		("2.2 – 2.4", "Wide bars top and bottom (cinema)"),
		("1.33 (4:3)", "Bars left and right"),
	]

	var body: some View {
		GroupBox {
			VStack(alignment: .leading, spacing: 10) {
				Text("Choosing video for a 16:9 TV")
					.font(.headline)
				Text("Check **Display Aspect Ratio** on the Video tab:")

				Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
					GridRow {
						Text("Display Aspect Ratio").bold()
						Text("On a 16:9 TV").bold()
					}
					Divider()
					ForEach(bands, id: \.ratio) { band in
						GridRow {
							Text(band.ratio).monospacedDigit()
							Text(band.result)
						}
					}
				}

				Text("The closer to **1.78**, the more of the screen is used. Resolution doesn't change the bars — only the ratio does.")
					.fixedSize(horizontal: false, vertical: true)

				Divider()

				Text("**DAR = (Width ÷ Height) × Sample Aspect Ratio**")
				Text("With square pixels (Sample Aspect Ratio 1) it's just Width ÷ Height, e.g. 1024 ÷ 428 = 2.39.")
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.font(.callout)
			.padding(6)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

private struct TabBarWidthKey: PreferenceKey {
	static let defaultValue: CGFloat = 0
	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = max(value, nextValue())
	}
}

private final class TabSelection: ObservableObject {
	@Published var tab: Tab = .general
}

struct ReportView: View {
	@ObservedObject var inspector: Inspector
	@StateObject private var selection = TabSelection()

	var body: some View {
		let layout = ReportLayout(rows: inspector.rows)
		let fileName = layout.fileName
		// Falls back to General when the new file lacks the selected kind
		let current = layout.tabs.contains(selection.tab) ? selection.tab : .general
		let shown = layout.groups(for: current)

		VStack(spacing: 0) {
			Picker("", selection: Binding(get: { current }, set: { selection.tab = $0 })) {
				ForEach(layout.tabs, id: \.self) { tab in
					Text(layout.label(for: tab)).tag(tab)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.fixedSize()
			.focusable(false)
			.background {
				GeometryReader { proxy in
					Color.clear.preference(key: TabBarWidthKey.self, value: proxy.size.width)
				}
			}
			.onPreferenceChange(TabBarWidthKey.self) { inspector.tabBarWidth = $0 }
			.padding(.bottom, 16)

			// ScrollView instead of Form: Form adds its own top inset inside the scroll area
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					if current == .general {
						GroupBox {
							VStack(spacing: 10) {
								if let thumbnail = inspector.thumbnail {
									Image(nsImage: thumbnail)
										.resizable()
										.scaledToFit()
										.frame(maxWidth: 160, maxHeight: 160)
										.clipShape(RoundedRectangle(cornerRadius: 10))
										.shadow(radius: 3, y: 1)
								} else if Shell.find("ffmpeg") == nil {
									FfmpegMissingView()
								}
								FileLink(name: fileName, inspector: inspector)
							}
							.frame(maxWidth: .infinity)
							.padding(8)
						}
					}
					ForEach(shown) { group in
						VStack(alignment: .leading, spacing: 6) {
							if let title = group.title, let section = group.section {
								Label(title, systemImage: section.symbol)
									.font(.headline)
									.foregroundStyle(section.tint)
									.padding(.leading, 4)
							}
							GroupBox {
								if let stream = group.stream, let cover = inspector.covers[stream] {
									Image(nsImage: cover)
										.resizable()
										.scaledToFit()
										.frame(maxWidth: 240, maxHeight: 240)
										.clipShape(RoundedRectangle(cornerRadius: 6))
										.shadow(radius: 2, y: 1)
										.frame(maxWidth: .infinity)
										.padding(.vertical, 8)
								} else if group.section == .cover, Shell.find("ffmpeg") == nil {
									// Full explanation is on the General tab
									Label("No preview: ffmpeg not found", systemImage: "exclamationmark.triangle.fill")
										.foregroundStyle(.secondary)
										.frame(maxWidth: .infinity)
										.padding(.vertical, 8)
								}
								// Label column sizes to the longest label; values share one left edge
								Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 0) {
									ForEach(Array(group.fields.enumerated()), id: \.element.id) { index, row in
										if index > 0 { Divider() }
										if case .field(let label) = row.kind {
											GridRow {
												Text(label + ":")
													.foregroundStyle(.secondary)
													.gridColumnAlignment(.trailing)
												Text(row.value)
													// Key value for judging TV fit (see start screen guide)
													.bold(label == "Display Aspect Ratio")
													.textSelection(.enabled)
													.frame(maxWidth: .infinity, alignment: .leading)
											}
											.padding(.vertical, 6)
										}
									}
								}
								.padding(.horizontal, 4)
							}
						}
					}
				}
				.padding(.horizontal, 20)
				.padding(.bottom, 20)
			}
		}
		.padding(.top, 12)
	}
}

// File name as a link: reveals the file in Finder
struct FileLink: View {
	let name: String
	@ObservedObject var inspector: Inspector

	var body: some View {
		Text(name)
			.font(.headline)
			.multilineTextAlignment(.center)
			.foregroundStyle(Color.accentColor)
			.underline(inspector.isTitleHovered)
			.onHover { hovering in
				inspector.isTitleHovered = hovering
				if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
			}
			.onTapGesture { inspector.revealInFinder() }
	}
}

private extension Row.Section {
	var symbol: String {
		switch self {
		case .video: "film"
		case .audio: "speaker.wave.2"
		case .text: "captions.bubble"
		case .cover: "photo"
		case .other: "doc"
		}
	}

	var tint: Color {
		switch self {
		case .video: .green
		case .audio: .blue
		case .text: .orange
		case .cover: .purple
		case .other: .secondary
		}
	}
}

struct BottomBar: View {
	@ObservedObject var inspector: Inspector

	var body: some View {
		HStack(spacing: 8) {
			iconButton("minus", help: "Clear", action: inspector.clear)
			iconButton("arrow.clockwise", help: "Reload", action: inspector.reload)
			Spacer()
			OpenButton(inspector: inspector)
		}
		.focusable(false)
		.padding(12)
	}

	// Fixed icon box: "minus" is shorter than other symbols
	private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Image(systemName: symbol).frame(width: 16, height: 16)
		}
		.help(help)
	}
}

struct OpenButton: View {
	@ObservedObject var inspector: Inspector

	var body: some View {
		Button {
			inspector.showOpenPanel()
		} label: {
			Label("Open Video File", systemImage: "doc")
		}
		.buttonStyle(.borderedProminent)
		.focusable(false)
	}
}
