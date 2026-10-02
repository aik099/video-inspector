import AppKit
import UniformTypeIdentifiers

struct Row: Identifiable {
	enum Kind {
		case fileName
		case section(Section)
		case field(label: String)
	}

	enum Section {
		case video, audio, text, cover, other

		init(stream: JSON) {
			let disposition = stream["disposition"] as? JSON ?? [:]
			if disposition["attached_pic"] as? Int == 1 {
				self = .cover
				return
			}
			switch stream["codec_type"] as? String {
			case "video": self = .video
			case "audio": self = .audio
			case "subtitle": self = .text
			default: self = .other
			}
		}
	}

	let id = UUID()
	let kind: Kind
	let value: String
	// ffprobe stream index, set on section rows
	var stream: Int?
}

typealias JSON = [String: Any]

// Video file types. The system registry alone isn't enough: a clean macOS doesn't know
// mkv, vob, etc. (players like VLC register them), so known extensions count too
enum VideoTypes {
	static let extensions: Set<String> = [
		"3g2", "3gp", "asf", "avi", "divx", "dv", "f4v", "flv", "m2t", "m2ts", "m2v", "m4v", "mkv", "mov",
		"mp4", "mpeg", "mpg", "mts", "mxf", "ogm", "ogv", "rm", "rmvb", "ts", "vob", "webm", "wmv",
	]

	// Fallback for extensions a clean macOS has no type (so no MIME type) for
	private static let mimeTypes = [
		"mkv": "video/matroska", "webm": "video/webm", "vob": "video/mpeg", "ogv": "video/ogg", "ogm": "video/ogg",
		"rm": "application/vnd.rn-realmedia", "rmvb": "application/vnd.rn-realmedia-vbr", "divx": "video/divx",
		"mxf": "application/mxf", "f4v": "video/mp4", "flv": "video/x-flv",
	]

	static func mimeType(_ ext: String) -> String? {
		UTType(filenameExtension: ext)?.preferredMIMEType ?? mimeTypes[ext.lowercased()]
	}

	// For open panels: movies the system knows, plus the extension list (dynamic types where unknown)
	static var contentTypes: [UTType] {
		[.movie] + extensions.sorted().compactMap { UTType(filenameExtension: $0) }
	}
}

extension URL {
	var isVideoFile: Bool {
		let ext = pathExtension.lowercased()
		return VideoTypes.extensions.contains(ext) || (UTType(filenameExtension: ext)?.conforms(to: .movie) ?? false)
	}
}

// Builds the report rows and thumbnail from ffprobe / ffmpeg output
enum Probe {
	static func inspect(_ url: URL) -> [Row] {
		let output = Shell.run("ffprobe", [
			"-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", url.path,
		])
		guard let root = try? JSONSerialization.jsonObject(with: output) as? JSON,
			let format = root["format"] as? JSON
		else {
			let error = Shell.find("ffprobe") == nil ? "ffprobe not found. \(Shell.installHint)" : "Not a readable video file"
			return [Row(kind: .field(label: "Error"), value: error)]
		}
		let streams = root["streams"] as? [JSON] ?? []

		var report = Report(fileName: url.lastPathComponent)
		report.addFormat(format, streams: streams, url: url)
		var countByType: [String: Int] = [:]
		for stream in streams {
			let type = stream["codec_type"] as? String ?? "data"
			report.addStream(stream, type: type, typeIndex: countByType[type, default: 0])
			countByType[type, default: 0] += 1
		}
		return report.rows
	}

	// Mirrors iSedora: with several video streams, cover art (mjpeg/png) wins; video frame is
	// taken 10% in (max 120 s); landscape is center-cropped square, portrait keeps its shape
	// Which video stream to grab and where; separate from decoding so tests can check it
	struct ThumbnailPlan: Equatable {
		let videoIndex: Int  // N in "-map 0:v:N"
		let seek: Int?  // seconds; nil for still images (cover art)
	}

	static func thumbnailPlan(_ url: URL) -> ThumbnailPlan? {
		let output = Shell.run("ffprobe", [
			"-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", "-select_streams", "v", url.path,
		])
		guard let root = try? JSONSerialization.jsonObject(with: output) as? JSON else { return nil }
		// Indices stay relative to all video streams, matching "-map 0:v:N"
		let streams = root["streams"] as? [JSON] ?? []
		let sized = streams.indices.filter {
			(streams[$0]["width"] as? Int ?? 0) > 0 && (streams[$0]["height"] as? Int ?? 0) > 0
		}
		let still = streams.count > 1
			? sized.first { ["mjpeg", "png"].contains(streams[$0]["codec_name"] as? String) }
			: nil
		guard let pick = still ?? sized.first ?? streams.indices.first else { return nil }

		if ["mjpeg", "png"].contains(streams[pick]["codec_name"] as? String) {
			return ThumbnailPlan(videoIndex: pick, seek: nil)
		}
		let format = root["format"] as? JSON ?? [:]
		let duration = (format["duration"] as? String).flatMap(Double.init) ?? 0
		return ThumbnailPlan(videoIndex: pick, seek: Int(min((duration * 0.1).rounded(), 120)))
	}

	static func thumbnail(_ url: URL) -> NSImage? {
		guard let plan = thumbnailPlan(url) else { return nil }
		var args = ["-v", "quiet"]
		if let seek = plan.seek { args += ["-ss", String(seek)] }
		args += [
			"-i", url.path, "-map", "0:v:\(plan.videoIndex)", "-an", "-sn",
			"-vf", "scale=-2:320,crop='min(iw,320)':320", "-frames:v", "1",
			"-f", "image2pipe", "-vcodec", "png", "-",
		]
		let png = Shell.run("ffmpeg", args)
		return png.isEmpty ? nil : NSImage(data: png)
	}
}

extension Probe {
	// Full image of one cover-art stream, downscaled to at most 320 px
	static func coverImage(_ url: URL, stream: Int) -> NSImage? {
		let png = Shell.run("ffmpeg", [
			"-v", "quiet", "-i", url.path, "-map", "0:\(stream)",
			"-vf", "scale='min(iw,320)':'min(ih,320)':force_original_aspect_ratio=decrease",
			"-frames:v", "1", "-f", "image2pipe", "-vcodec", "png", "-",
		])
		return png.isEmpty ? nil : NSImage(data: png)
	}
}

private struct Report {
	private(set) var rows: [Row]

	init(fileName: String) {
		rows = [Row(kind: .fileName, value: fileName)]
	}

	mutating func addFormat(_ format: JSON, streams: [JSON], url: URL) {
		let types = streams.compactMap { $0["codec_type"] as? String }
		add("Media Type", types.contains("video") ? "Video" : types.contains("audio") ? "Audio" : nil)
		add("Mime Type", VideoTypes.mimeType(url.pathExtension))
		add("Format", "\(format["format_long_name"] ?? "") [\(format["format_name"] ?? "")]")
		add("Duration", number(format, "duration").map(Format.duration))
		add("Bitrate", number(format, "bit_rate").map(Format.bitrate))
		add("File Size", number(format, "size").map(Format.fileSize))

		let tags = format["tags"] as? JSON ?? [:]
		for key in ["title", "artist", "composer", "album", "track", "genre", "date", "comment"] {
			add(key.capitalized, tags[key] ?? tags[key.uppercased()])
		}
	}

	mutating func addStream(_ stream: JSON, type: String, typeIndex: Int) {
		let section = Row.Section(stream: stream)
		let name = switch section {
		case .video: "Video"
		case .audio: "Audio"
		case .text: "Text"
		case .cover: "Cover Art"
		case .other: type.capitalized
		}
		let index = stream["index"] as? Int ?? 0
		rows.append(Row(kind: .section(section), value: "\(name) [\(index):\(typeIndex)]", stream: index))

		let tags = stream["tags"] as? JSON ?? [:]
		let disposition = stream["disposition"] as? JSON ?? [:]

		add("Codec", "\(stream["codec_long_name"] ?? "") [\(stream["codec_name"] ?? "")]")
		add("File Name", tags["filename"])
		add("Profile", stream["profile"])
		add("Duration", number(stream, "duration").map(Format.duration))
		if let width = stream["width"], let height = stream["height"] {
			add("Width / Height", "\(width) x \(height)")
		}
		add("Sample Aspect Ratio", Format.ratio(stream["sample_aspect_ratio"] as? String, separator: ":"))
		add("Display Aspect Ratio", Format.ratio(stream["display_aspect_ratio"] as? String, separator: ":"))
		if section == .video, let dar = displayAspect(stream) {
			add("On 16:9 TV", Format.tvFit(dar))
		}
		add("Picture Format", stream["pix_fmt"])
		if section == .video {
			add("Framerate", Format.ratio(stream["avg_frame_rate"] as? String, separator: "/"))
		}
		add("Sample Format", stream["sample_fmt"])
		add("Sample Rate", stream["sample_rate"])
		add("Channels", stream["channels"])
		add("Channel Layout", stream["channel_layout"])
		add("Bitrate", number(stream, "bit_rate").map(Format.bitrate))
		add("Title", tags["title"])
		if disposition["default"] as? Int == 1 { add("Default", "true") }
		if disposition["forced"] as? Int == 1 { add("Forced", "true") }
		add("Language", tags["language"])
	}

	// Skips missing and placeholder values
	private mutating func add(_ label: String, _ value: Any?) {
		guard let value else { return }
		let text = "\(value)"
		guard !["", "N/A", "unknown"].contains(text) else { return }
		rows.append(Row(kind: .field(label: label), value: text))
	}

	// display_aspect_ratio when present, else width ÷ height × sample aspect ratio
	private func displayAspect(_ stream: JSON) -> Double? {
		if let dar = Format.value(stream["display_aspect_ratio"] as? String, separator: ":") { return dar }
		guard let width = stream["width"] as? Int, let height = stream["height"] as? Int, height > 0 else { return nil }
		let sar = Format.value(stream["sample_aspect_ratio"] as? String, separator: ":") ?? 1
		return Double(width) / Double(height) * sar
	}

	// ffprobe reports numbers as strings
	private func number(_ object: JSON, _ key: String) -> Double? {
		(object[key] as? String).flatMap(Double.init)
	}
}
