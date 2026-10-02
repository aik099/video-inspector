import AppKit

// Snapshot + unit tests for the non-UI code (Probe, Format, ReportLayout).
// Usage: ./test.sh [--update]
let update = CommandLine.arguments.contains("--update")
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let fixtures = root.appendingPathComponent("tests/fixtures")
let expectedDir = root.appendingPathComponent("tests/expected")
var failures = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
	if !condition {
		print("FAIL: \(message())")
		failures += 1
	}
}

// Text version of what the UI shows: tabs, cards, rows, thumbnail and cover previews
func snapshot(_ url: URL) -> String {
	let layout = ReportLayout(rows: Probe.inspect(url))
	var lines = ["== Tabs: " + layout.tabs.map(layout.label(for:)).joined(separator: ", ")]
	lines.append("[file] \(layout.fileName)")
	for tab in layout.tabs {
		lines.append("")
		lines.append("== \(layout.label(for: tab))")
		for group in layout.groups(for: tab) {
			if let title = group.title { lines.append("[\(title)]") }
			for row in group.fields {
				if case .field(let label) = row.kind { lines.append("\(label): \(row.value)") }
			}
			if group.section == .cover, let stream = group.stream {
				lines.append("(preview: \(imageSize(Probe.coverImage(url, stream: stream))))")
			}
		}
	}
	lines.append("")
	if let plan = Probe.thumbnailPlan(url) {
		let seek = plan.seek.map { "seek \($0) s" } ?? "still image"
		lines.append("== Thumbnail: v:\(plan.videoIndex), \(seek), \(imageSize(Probe.thumbnail(url)))")
	} else {
		lines.append("== Thumbnail: none")
	}
	return lines.joined(separator: "\n") + "\n"
}

func imageSize(_ image: NSImage?) -> String {
	guard let rep = image?.representations.first else { return "no image" }
	return "\(rep.pixelsWide)x\(rep.pixelsHigh)"
}

// Snapshots: one expected file per fixture
let names = (try? FileManager.default.contentsOfDirectory(atPath: fixtures.path)) ?? []
let videos = names.filter { URL(fileURLWithPath: $0).isVideoFile }.sorted()
check(!videos.isEmpty, "no fixtures in \(fixtures.path)")
for name in videos {
	let actual = snapshot(fixtures.appendingPathComponent(name))
	let expectedURL = expectedDir.appendingPathComponent(name + ".txt")
	if update {
		try! actual.write(to: expectedURL, atomically: true, encoding: .utf8)
		print("updated \(expectedURL.lastPathComponent)")
		continue
	}
	let expected = (try? String(contentsOf: expectedURL, encoding: .utf8)) ?? ""
	if actual == expected {
		print("ok    \(name)")
	} else {
		failures += 1
		print("FAIL  \(name) (expected \(expectedURL.lastPathComponent)); diff (- expected, + actual):")
		let old = expected.components(separatedBy: "\n"), new = actual.components(separatedBy: "\n")
		for line in old where !new.contains(line) { print("  - \(line)") }
		for line in new where !old.contains(line) { print("  + \(line)") }
	}
}

// Unit checks: formatting and file-type rules
check(Format.tvFit(1024.0 / 428) == "Bars top and bottom, 139 px each", "tvFit 2.39")
check(Format.tvFit(16.0 / 9) == "Fills the whole screen", "tvFit 16:9")
check(Format.tvFit(1.76) == "Fills the whole screen", "tvFit within 2 %")
check(Format.tvFit(4.0 / 3) == "Bars left and right, 240 px each", "tvFit 4:3")
check(Format.ratio("24000/1001", separator: "/") == "23.976", "ratio 23.976")
check(Format.ratio("1:1", separator: ":") == "1", "ratio 1:1")
check(Format.ratio("0:1", separator: ":") == nil, "ratio 0:1 is missing")
check(Format.duration(6684) == "01:51:24", "duration")
check(Format.bitrate(448_000) == "448 Kbps" && Format.bitrate(3_000_000) == "3 Mbps", "bitrate")
for ext in ["mkv", "avi", "mp4", "mov", "ts", "webm", "m2ts", "vob"] {
	check(URL(fileURLWithPath: "a.\(ext)").isVideoFile, "\(ext) is video")
}
for ext in ["jpg", "png", "mp3", "txt", "srt"] {
	check(!URL(fileURLWithPath: "a.\(ext)").isVideoFile, "\(ext) is not video")
}

if update {
	print("snapshots updated; review with git diff tests/expected")
} else if failures > 0 {
	print("\(failures) failure(s)")
	exit(1)
} else {
	print("all tests passed")
}
