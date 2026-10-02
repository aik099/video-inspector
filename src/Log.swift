import Foundation

// Opt-in debug log: `defaults write aik099.video-inspector DebugLogging -bool YES`
// Output: ~/Library/Logs/Video Inspector.log
enum Log {
	private static let isEnabled = UserDefaults.standard.bool(forKey: "DebugLogging")
	private static let url = FileManager.default.homeDirectoryForCurrentUser
		.appendingPathComponent("Library/Logs/Video Inspector.log")
	private static let queue = DispatchQueue(label: "log")
	private static let timestamp: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
		return formatter
	}()

	// Autoclosure: message isn't built when logging is off
	static func debug(_ message: @autoclosure () -> String) {
		guard isEnabled else { return }
		let line = "\(timestamp.string(from: Date())) \(message())\n"
		queue.async {
			guard let data = line.data(using: .utf8) else { return }
			if let handle = try? FileHandle(forWritingTo: url) {
				handle.seekToEndOfFile()
				handle.write(data)
				try? handle.close()
			} else {
				try? data.write(to: url)
			}
		}
	}
}
