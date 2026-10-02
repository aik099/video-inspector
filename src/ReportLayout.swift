import Foundation

// Rows grouped into tabs and cards; shared by the UI and the snapshot tests
struct RowGroup: Identifiable {
	let id = UUID()
	var title: String?
	var section: Row.Section?
	var stream: Int?
	var fields: [Row] = []
}

// Tab per stream kind; only kinds present in the file are shown
enum Tab: Hashable {
	case general
	case streams(Row.Section)

	var title: String {
		switch self {
		case .general: "General"
		case .streams(.video): "Video"
		case .streams(.audio): "Audio"
		case .streams(.text): "Subtitles"
		case .streams(.cover): "Cover Art"
		case .streams(.other): "Other"
		}
	}
}

struct ReportLayout {
	let fileName: String
	let general: [RowGroup]
	let streams: [RowGroup]
	let tabs: [Tab]

	init(rows: [Row]) {
		var fileName = ""
		var groups = [RowGroup()]
		for row in rows {
			switch row.kind {
			case .fileName: fileName = row.value
			case .section(let section): groups.append(RowGroup(title: row.value, section: section, stream: row.stream))
			case .field: groups[groups.count - 1].fields.append(row)
			}
		}
		groups = groups.filter { !$0.fields.isEmpty || $0.title != nil }

		let streams = groups.filter { $0.section != nil }
		let kinds: [Row.Section] = [.video, .audio, .text, .cover, .other]
		self.fileName = fileName
		self.streams = streams
		general = groups.filter { $0.section == nil }
		tabs = [.general] + kinds.filter { kind in streams.contains { $0.section == kind } }.map(Tab.streams)
	}

	func groups(for tab: Tab) -> [RowGroup] {
		switch tab {
		case .general: general
		case .streams(let kind): streams.filter { $0.section == kind }
		}
	}

	// "Audio (2)" when there are several streams of a kind
	func label(for tab: Tab) -> String {
		guard case .streams = tab else { return tab.title }
		let count = groups(for: tab).count
		return count > 1 ? "\(tab.title) (\(count))" : tab.title
	}
}
