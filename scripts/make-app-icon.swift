#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Original vector artwork by Codex for How to Adult, 2026-10-03.
// An open pocket guide with a checked bookmark. No stock art or generated raster.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let rgb = CGColorSpaceCreateDeviceRGB()

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgb, components: [r / 255, g / 255, b / 255, a])!
}

func makeIcon(size: Int, mac: Bool, name: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    if mac {
        context.translateBy(x: 54, y: 54)
        context.scaleBy(x: 916 / 1024, y: 916 / 1024)
        context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024), cornerWidth: 204, cornerHeight: 204, transform: nil))
        context.clip()
    }
    let gradient = CGGradient(colorsSpace: rgb, colors: [color(18, 60, 114), color(29, 83, 147)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 160, y: 0), end: CGPoint(x: 864, y: 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    let cover = CGMutablePath()
    cover.move(to: CGPoint(x: 229, y: 734))
    cover.addQuadCurve(to: CGPoint(x: 510, y: 700), control: CGPoint(x: 382, y: 799))
    cover.addQuadCurve(to: CGPoint(x: 795, y: 734), control: CGPoint(x: 641, y: 800))
    cover.addLine(to: CGPoint(x: 795, y: 300))
    cover.addQuadCurve(to: CGPoint(x: 510, y: 256), control: CGPoint(x: 638, y: 337))
    cover.addQuadCurve(to: CGPoint(x: 229, y: 300), control: CGPoint(x: 384, y: 337))
    cover.closeSubpath()
    context.setFillColor(color(187, 214, 239))
    context.addPath(cover)
    context.fillPath()

    let left = CGMutablePath()
    left.move(to: CGPoint(x: 250, y: 767))
    left.addQuadCurve(to: CGPoint(x: 503, y: 709), control: CGPoint(x: 402, y: 812))
    left.addLine(to: CGPoint(x: 503, y: 295))
    left.addQuadCurve(to: CGPoint(x: 250, y: 330), control: CGPoint(x: 379, y: 364))
    left.closeSubpath()
    context.setFillColor(color(255, 255, 255))
    context.addPath(left)
    context.fillPath()

    let right = CGMutablePath()
    right.move(to: CGPoint(x: 521, y: 709))
    right.addQuadCurve(to: CGPoint(x: 774, y: 767), control: CGPoint(x: 622, y: 812))
    right.addLine(to: CGPoint(x: 774, y: 330))
    right.addQuadCurve(to: CGPoint(x: 521, y: 295), control: CGPoint(x: 647, y: 364))
    right.closeSubpath()
    context.addPath(right)
    context.fillPath()

    context.setStrokeColor(color(18, 60, 114, 0.19))
    context.setLineWidth(22)
    context.setLineCap(.round)
    for (y, end) in [(620.0, 432.0), (546.0, 424.0), (472.0, 390.0)] {
        context.move(to: CGPoint(x: 318, y: y))
        context.addLine(to: CGPoint(x: end, y: y - 9))
        context.strokePath()
    }

    let bookmark = CGMutablePath()
    bookmark.move(to: CGPoint(x: 618, y: 766))
    bookmark.addQuadCurve(to: CGPoint(x: 718, y: 782), control: CGPoint(x: 667, y: 781))
    bookmark.addLine(to: CGPoint(x: 718, y: 523))
    bookmark.addLine(to: CGPoint(x: 668, y: 561))
    bookmark.addLine(to: CGPoint(x: 618, y: 523))
    bookmark.closeSubpath()
    context.setFillColor(color(229, 84, 55))
    context.addPath(bookmark)
    context.fillPath()
    context.setStrokeColor(color(255, 255, 255))
    context.setLineWidth(16)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: 640, y: 657))
    context.addLine(to: CGPoint(x: 659, y: 637))
    context.addLine(to: CGPoint(x: 695, y: 680))
    context.strokePath()

    // iOS icons must have no alpha channel, even though every rendered pixel is opaque.
    let output: NSBitmapImageRep
    if mac {
        output = bitmap
    } else {
        output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 24)!
        for y in 0..<size {
            for x in 0..<size {
                let rgba = bitmap.bitmapData! + y * bitmap.bytesPerRow + x * 4
                let rgb = output.bitmapData! + y * output.bytesPerRow + x * 3
                rgb[0] = rgba[0]
                rgb[1] = rgba[1]
                rgb[2] = rgba[2]
            }
        }
    }
    guard let png = output.representation(using: .png, properties: [:]) else { fatalError("Unable to encode app icon") }
    try png.write(to: folder.appendingPathComponent(name))
}

try makeIcon(size: 1024, mac: false, name: "AppIcon-iOS-1024.png")
var entries: [[String: String]] = [["filename": "AppIcon-iOS-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]]
for nominal in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = nominal * scale
        let filename = "AppIcon-mac-\(nominal)@\(scale)x.png"
        try makeIcon(size: size, mac: true, name: filename)
        entries.append(["filename": filename, "idiom": "mac", "size": "\(nominal)x\(nominal)", "scale": "\(scale)x"])
    }
}
let json = try JSONSerialization.data(withJSONObject: ["images": entries, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
try json.write(to: folder.appendingPathComponent("Contents.json"))
print("Original app icon rendered: iOS full bleed + macOS 10 required sizes.")
