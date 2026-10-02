import AppKit

// Renders the app icon (1024 px) to icon.png
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824 px tile centered in 1024 canvas
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(tilePath)
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()
ctx.restoreGState()
ctx.addPath(tilePath)
ctx.clip()
let grad = CGGradient(colorsSpace: nil, colors: [
	NSColor(red: 0.26, green: 0.55, blue: 0.79, alpha: 1).cgColor,
	NSColor(red: 0.13, green: 0.30, blue: 0.52, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

// Film strip
let film = CGRect(x: 232, y: 352, width: 560, height: 400)
ctx.addPath(CGPath(roundedRect: film, cornerWidth: 36, cornerHeight: 36, transform: nil))
ctx.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
ctx.fillPath()
ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
for i in 0..<6 {
	let x = film.minX + 38 + CGFloat(i) * 86
	for y in [film.minY + 22, film.maxY - 62] {
		ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: 50, height: 40), cornerWidth: 8, cornerHeight: 8, transform: nil))
	}
}
ctx.fillPath()
// Frame picture
let frame = CGRect(x: film.minX + 32, y: film.minY + 88, width: film.width - 64, height: film.height - 176)
let pic = CGGradient(colorsSpace: nil, colors: [
	NSColor(red: 0.98, green: 0.78, blue: 0.35, alpha: 1).cgColor,
	NSColor(red: 0.36, green: 0.72, blue: 0.36, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
ctx.saveGState()
ctx.clip(to: frame)
ctx.drawLinearGradient(pic, start: CGPoint(x: 0, y: frame.maxY), end: CGPoint(x: 0, y: frame.minY), options: [])
// Play triangle
ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
ctx.move(to: CGPoint(x: frame.midX - 40, y: frame.midY + 50))
ctx.addLine(to: CGPoint(x: frame.midX - 40, y: frame.midY - 50))
ctx.addLine(to: CGPoint(x: frame.midX + 50, y: frame.midY))
ctx.fillPath()
ctx.restoreGState()

// Magnifier: metal ring, tinted glass with highlight, dark handle with ferrule
let c = CGPoint(x: 625, y: 435), r: CGFloat = 125, ring: CGFloat = 30
let angle = -CGFloat.pi / 4
func rotated(_ body: () -> Void) {
	ctx.saveGState()
	ctx.translateBy(x: c.x, y: c.y)
	ctx.rotate(by: angle)
	body()
	ctx.restoreGState()
}
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.45).cgColor)
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
rotated {
	// Handle
	let handle = CGRect(x: r + 46, y: -34, width: 140, height: 68)
	ctx.saveGState()
	ctx.addPath(CGPath(roundedRect: handle, cornerWidth: 34, cornerHeight: 34, transform: nil))
	ctx.clip()
	let hg = CGGradient(colorsSpace: nil, colors: [
		NSColor(white: 0.32, alpha: 1).cgColor, NSColor(white: 0.10, alpha: 1).cgColor,
		NSColor(white: 0.22, alpha: 1).cgColor] as CFArray, locations: [0, 0.6, 1])!
	ctx.drawLinearGradient(hg, start: CGPoint(x: 0, y: 34), end: CGPoint(x: 0, y: -34), options: [])
	ctx.restoreGState()
	// Ferrule
	let ferrule = CGRect(x: r + ring - 6, y: -26, width: 62, height: 52)
	ctx.saveGState()
	ctx.addPath(CGPath(roundedRect: ferrule, cornerWidth: 8, cornerHeight: 8, transform: nil))
	ctx.clip()
	let fg = CGGradient(colorsSpace: nil, colors: [
		NSColor(white: 0.95, alpha: 1).cgColor, NSColor(white: 0.62, alpha: 1).cgColor,
		NSColor(white: 0.82, alpha: 1).cgColor] as CFArray, locations: [0, 0.6, 1])!
	ctx.drawLinearGradient(fg, start: CGPoint(x: 0, y: 26), end: CGPoint(x: 0, y: -26), options: [])
	ctx.restoreGState()
}
// Ring
let outer = CGRect(x: c.x - r - ring, y: c.y - r - ring, width: 2 * (r + ring), height: 2 * (r + ring))
ctx.saveGState()
ctx.addEllipse(in: outer)
ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
ctx.clip(using: .evenOdd)
let rg = CGGradient(colorsSpace: nil, colors: [
	NSColor(white: 0.98, alpha: 1).cgColor, NSColor(white: 0.70, alpha: 1).cgColor,
	NSColor(white: 0.88, alpha: 1).cgColor] as CFArray, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(rg, start: CGPoint(x: outer.minX, y: outer.maxY), end: CGPoint(x: outer.maxX, y: outer.minY), options: [])
ctx.restoreGState()
ctx.endTransparencyLayer()
ctx.restoreGState()
// Glass
let glass = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
ctx.saveGState()
ctx.addEllipse(in: glass)
ctx.clip()
let gg = CGGradient(colorsSpace: nil, colors: [
	NSColor(red: 0.75, green: 0.88, blue: 1, alpha: 0.30).cgColor,
	NSColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 0.45).cgColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gg, start: CGPoint(x: glass.minX, y: glass.maxY), end: CGPoint(x: glass.maxX, y: glass.minY), options: [])
// Highlight arc
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
ctx.setLineWidth(16)
ctx.setLineCap(.round)
ctx.addArc(center: c, radius: r - 30, startAngle: .pi * 0.58, endAngle: .pi * 0.92, clockwise: false)
ctx.strokePath()
ctx.restoreGState()
// Inner rim shade
ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.25).cgColor)
ctx.setLineWidth(4)
ctx.strokeEllipse(in: glass.insetBy(dx: 2, dy: 2))

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Resources/icon.png"))
