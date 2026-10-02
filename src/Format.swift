import Foundation

enum Format {
	static func duration(_ seconds: Double) -> String {
		let total = Int(seconds.rounded())
		return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
	}

	static func bitrate(_ bps: Double) -> String {
		bps >= 1_000_000
			? "\(Int((bps / 1_000_000).rounded())) Mbps"
			: "\(Int((bps / 1000).rounded())) Kbps"
	}

	static func fileSize(_ bytes: Double) -> String {
		ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
	}

	// "24000/1001" -> 23.976; nil for missing, zero or malformed
	static func value(_ text: String?, separator: Character) -> Double? {
		guard let text, let split = text.firstIndex(of: separator),
			let a = Double(text[..<split]),
			let b = Double(text[text.index(after: split)...]),
			a != 0, b != 0
		else { return nil }
		return a / b
	}

	// "24000/1001" -> "23.976", "16:9" -> "1.778", "1:1" -> "1"
	static func ratio(_ text: String?, separator: Character) -> String? {
		guard let value = value(text, separator: separator) else { return nil }
		return value == value.rounded() ? String(Int(value)) : String(format: "%.3f", value)
	}

	// Picture on a 1920×1080 (16:9) screen; within 2% of 16:9 counts as full screen
	static func tvFit(_ dar: Double) -> String {
		let screen = 16.0 / 9.0
		if abs(dar - screen) / screen <= 0.02 { return "Fills the whole screen" }
		if dar > screen {
			let bar = Int(((1080 - 1920 / dar) / 2).rounded())
			return "Bars top and bottom, \(bar) px each"
		}
		let bar = Int(((1920 - 1080 * dar) / 2).rounded())
		return "Bars left and right, \(bar) px each"
	}
}
