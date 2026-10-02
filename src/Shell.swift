import Foundation

enum Shell {
	private static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", "/usr/bin"]

	static var searchFolders: String {
		searchPaths.joined(separator: ", ")
	}

	// Install-method neutral: static builds, Homebrew, MacPorts all end up in one of the search folders
	static var installHint: String {
		"Put ffprobe and ffmpeg into one of: \(searchFolders)"
	}

	// osxexperts.net: arm64 and Intel; evermeet.cx (the only macOS option on ffmpeg.org): Intel only
	static let downloadLinks: [(title: String, url: URL)] = [
		("osxexperts.net (Apple Silicon & Intel)", URL(string: "https://www.osxexperts.net")!),
		("evermeet.cx/ffmpeg (Intel)", URL(string: "https://evermeet.cx/ffmpeg/")!),
	]

	static func find(_ tool: String) -> String? {
		searchPaths
			.map { "\($0)/\(tool)" }
			.first { FileManager.default.isExecutableFile(atPath: $0) }
	}

	// Returns stdout; empty when the tool is missing or fails to start
	static func run(_ tool: String, _ args: [String]) -> Data {
		guard let path = find(tool) else { return Data() }

		let process = Process()
		process.executableURL = URL(fileURLWithPath: path)
		process.arguments = args
		let stdout = Pipe()
		process.standardOutput = stdout
		process.standardError = FileHandle.nullDevice

		do {
			try process.run()
		} catch {
			return Data()
		}
		let data = stdout.fileHandleForReading.readDataToEndOfFile()
		process.waitUntilExit()
		return data
	}
}
