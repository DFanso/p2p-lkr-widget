#!/usr/bin/env swift
//
// Renders the app icon at every size the macOS asset catalog needs.
//
//   swift tools/make-icon.swift [output-dir]
//
// The icon is a rising sparkline over an emerald ground, with the Sri Lankan
// rupee glyph watermarked behind it. Deliberately carries no Binance or Tether
// branding — those are trademarks, and borrowing them would misrepresent this
// as an official client.
//
// Below 64px the watermark and a hairline stroke turn to mud, so small sizes
// render ground-plus-line only and the stroke scales with the canvas.

import AppKit
import Foundation

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "P2PMonitor/Assets.xcassets/AppIcon.appiconset"

/// macOS draws icon artwork inside 824pt of a 1024pt canvas, leaving margin
/// for the system's own shadow. Keeping that ratio makes the icon sit
/// correctly next to Apple's own.
let bodyRatio: CGFloat = 824.0 / 1024.0

/// Superellipse exponent. 5 lands close to Apple's continuous-corner squircle;
/// a plain rounded rect reads visibly wrong beside system icons.
let squircleExponent: CGFloat = 5

func squircle(in rect: CGRect, exponent n: CGFloat = squircleExponent) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.line(to: CGPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

/// Normalised sparkline, x and y in 0...1 of the body rect. A clear net rise
/// with enough wobble to read as real data rather than a generic arrow.
let series: [CGPoint] = [
    CGPoint(x: 0.10, y: 0.30),
    CGPoint(x: 0.22, y: 0.37),
    CGPoint(x: 0.33, y: 0.28),
    CGPoint(x: 0.45, y: 0.45),
    CGPoint(x: 0.56, y: 0.40),
    CGPoint(x: 0.68, y: 0.58),
    CGPoint(x: 0.79, y: 0.51),
    CGPoint(x: 0.90, y: 0.72),
]

/// At 16px each segment of the full series is barely a pixel wide, so the
/// wobble reads as noise rather than data. Three segments still say "rising"
/// and stay crisp.
let seriesTiny: [CGPoint] = [
    CGPoint(x: 0.13, y: 0.28),
    CGPoint(x: 0.38, y: 0.44),
    CGPoint(x: 0.62, y: 0.38),
    CGPoint(x: 0.87, y: 0.70),
]

func render(pixels px: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { fatalError("could not allocate \(px)px bitmap") }
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("could not make context")
    }
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    let canvas = CGFloat(px)
    let bodySide = canvas * bodyRatio
    let body = CGRect(x: (canvas - bodySide) / 2, y: (canvas - bodySide) / 2,
                      width: bodySide, height: bodySide)
    let shape = squircle(in: body)

    // Emerald ground, light from above per the platform convention.
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.063, green: 0.725, blue: 0.506, alpha: 1),  // #10B981
        NSColor(srgbRed: 0.024, green: 0.306, blue: 0.231, alpha: 1),  // #064E3B
    ])!
    gradient.draw(in: shape, angle: -90)

    shape.addClip()

    // The watermark and a thin stroke both disappear at 16-32px, so the small
    // renders drop the glyph and thicken the line instead.
    let isSmall = px < 64

    if !isSmall {
        let fontSize = bodySide * 0.60
        // CoreText falls back to a Sinhala face for this glyph; the system
        // font alone does not carry it.
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let text = NSAttributedString(string: "රු", attributes: [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.12),
        ])
        let size = text.size()
        text.draw(at: CGPoint(x: body.midX - size.width / 2,
                              y: body.midY - size.height / 2))
    }

    let line = NSBezierPath()
    let points = px <= 16 ? seriesTiny : series
    for (index, point) in points.enumerated() {
        let p = CGPoint(x: body.minX + point.x * bodySide,
                        y: body.minY + point.y * bodySide)
        if index == 0 { line.move(to: p) } else { line.line(to: p) }
    }
    line.lineWidth = bodySide * (isSmall ? 0.105 : 0.072)
    line.lineCapStyle = .round
    line.lineJoinStyle = .round

    if !isSmall {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = bodySide * 0.035
        shadow.shadowOffset = NSSize(width: 0, height: -bodySide * 0.018)
        shadow.set()
    }
    NSColor.white.setStroke()
    line.stroke()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed at \(px)px")
    }
    return data
}

/// (filename, pixel size) for every macOS AppIcon slot.
let slots: [(name: String, px: Int, size: String, scale: String)] = [
    ("icon_16x16.png",       16,  "16x16",   "1x"),
    ("icon_16x16@2x.png",    32,  "16x16",   "2x"),
    ("icon_32x32.png",       32,  "32x32",   "1x"),
    ("icon_32x32@2x.png",    64,  "32x32",   "2x"),
    ("icon_128x128.png",     128, "128x128", "1x"),
    ("icon_128x128@2x.png",  256, "128x128", "2x"),
    ("icon_256x256.png",     256, "256x256", "1x"),
    ("icon_256x256@2x.png",  512, "256x256", "2x"),
    ("icon_512x512.png",     512, "512x512", "1x"),
    ("icon_512x512@2x.png",  1024, "512x512", "2x"),
]

try FileManager.default.createDirectory(atPath: outputDir,
                                        withIntermediateDirectories: true)

// Distinct pixel sizes are rendered once and reused across slots that share
// them: 16@2x and 32@1x are the same 32px image.
var cache: [Int: Data] = [:]
for slot in slots {
    let data = cache[slot.px] ?? render(pixels: slot.px)
    cache[slot.px] = data
    let path = (outputDir as NSString).appendingPathComponent(slot.name)
    try data.write(to: URL(fileURLWithPath: path))
    print("wrote \(slot.name) (\(slot.px)px, \(data.count) bytes)")
}

let entries = slots.map { slot in
    """
        {
          "filename" : "\(slot.name)",
          "idiom" : "mac",
          "scale" : "\(slot.scale)",
          "size" : "\(slot.size)"
        }
    """
}.joined(separator: ",\n")

let contents = """
{
  "images" : [
\(entries)
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try contents.write(toFile: (outputDir as NSString).appendingPathComponent("Contents.json"),
                   atomically: true, encoding: .utf8)
print("wrote Contents.json (\(slots.count) slots, \(cache.count) unique renders)")
