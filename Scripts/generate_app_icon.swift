#!/usr/bin/swift

import AppKit
import Foundation

struct IconSlot: Encodable {
    let idiom: String
    let size: String
    let scale: String
    let filename: String
}

struct AssetContents: Encodable {
    struct Metadata: Encodable {
        let author: String
        let version: Int
    }

    let images: [IconSlot]?
    let info: Metadata
}

private let colorSpace = CGColorSpaceCreateDeviceRGB()

private let iconSlots: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

let arguments = CommandLine.arguments
let rootPath: String
if let rootIndex = arguments.firstIndex(of: "--root"), arguments.indices.contains(rootIndex + 1) {
    rootPath = arguments[rootIndex + 1]
} else {
    rootPath = FileManager.default.currentDirectoryPath
}

let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
let assetsURL = rootURL.appendingPathComponent("Sources/Assets.xcassets", isDirectory: true)
let appIconURL = assetsURL.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let designURL = rootURL.appendingPathComponent("Design", isDirectory: true)

try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: appIconURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: designURL, withIntermediateDirectories: true)

let previewURL = designURL.appendingPathComponent("zipper-logo-preview.png")
let masterURL = designURL.appendingPathComponent("zipper-logo-master.png")

let assetCatalogContents = AssetContents(images: nil, info: .init(author: "xcode", version: 1))
try writeJSON(assetCatalogContents, to: assetsURL.appendingPathComponent("Contents.json"))

let appIconContents = AssetContents(
    images: iconSlots.map { slot in
        IconSlot(
            idiom: "mac",
            size: "\(slot.points)x\(slot.points)",
            scale: "\(slot.scale)x",
            filename: "icon_\(slot.points)x\(slot.points)\(slot.scale == 2 ? "@2x" : "").png"
        )
    },
    info: .init(author: "xcode", version: 1)
)
try writeJSON(appIconContents, to: appIconURL.appendingPathComponent("Contents.json"))

try writePNG(for: 1024, to: masterURL)
try writePNG(for: 512, to: previewURL)

for slot in iconSlots {
    let pixelSize = slot.points * slot.scale
    let destinationURL = appIconURL.appendingPathComponent("icon_\(slot.points)x\(slot.points)\(slot.scale == 2 ? "@2x" : "").png")
    try writePNG(for: pixelSize, to: destinationURL)
}

print("Created preview at \(previewURL.path)")
print("Created app icons at \(appIconURL.path)")

func writePNG(for pixelSize: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap context"])
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    let cgContext = graphicsContext.cgContext
    cgContext.interpolationQuality = .high
    renderIcon(in: cgContext, size: CGFloat(pixelSize))

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    try data.write(to: url, options: .atomic)
}

func renderIcon(in context: CGContext, size: CGFloat) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let outerInset = size * 0.046
    let outerRect = canvas.insetBy(dx: outerInset, dy: outerInset)
    let outerRadius = size * 0.22

    context.clear(canvas)

    let outerPath = roundedPath(outerRect, radius: outerRadius)
    context.saveGState()
    context.addPath(outerPath)
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [
            color(0.17, 0.18, 0.20),
            color(0.10, 0.11, 0.12),
            color(0.05, 0.05, 0.06),
        ],
        locations: [0.0, 0.45, 1.0],
        start: CGPoint(x: outerRect.minX, y: outerRect.maxY),
        end: CGPoint(x: outerRect.maxX, y: outerRect.minY)
    )

    drawRadialGradient(
        in: context,
        colors: [
            color(0.98, 0.85, 0.32, alpha: 0.22),
            color(0.98, 0.85, 0.32, alpha: 0.0),
        ],
        locations: [0.0, 1.0],
        startCenter: CGPoint(x: outerRect.midX, y: outerRect.midY + size * 0.04),
        startRadius: size * 0.01,
        endCenter: CGPoint(x: outerRect.midX, y: outerRect.midY + size * 0.04),
        endRadius: size * 0.34
    )

    let mistRect = CGRect(x: outerRect.minX, y: outerRect.minY, width: outerRect.width, height: outerRect.height * 0.45)
    drawRadialGradient(
        in: context,
        colors: [
            color(1.0, 1.0, 1.0, alpha: 0.10),
            color(1.0, 1.0, 1.0, alpha: 0.0),
        ],
        locations: [0.0, 1.0],
        startCenter: CGPoint(x: mistRect.minX + mistRect.width * 0.22, y: mistRect.maxY),
        startRadius: size * 0.01,
        endCenter: CGPoint(x: mistRect.minX + mistRect.width * 0.22, y: mistRect.maxY),
        endRadius: size * 0.48
    )
    context.restoreGState()

    context.addPath(outerPath)
    context.setLineWidth(size * 0.01)
    context.setStrokeColor(color(1.0, 1.0, 1.0, alpha: 0.08))
    context.strokePath()

    context.saveGState()
    context.setShadow(offset: .zero, blur: size * 0.055, color: color(0.90, 0.76, 0.18, alpha: 0.26))
    let glowRect = CGRect(x: size * 0.30, y: size * 0.20, width: size * 0.40, height: size * 0.56)
    context.addEllipse(in: glowRect)
    context.setFillColor(color(0.90, 0.76, 0.18, alpha: 0.16))
    context.fillPath()
    context.restoreGState()

    let bodyRect = CGRect(x: size * 0.355, y: size * 0.18, width: size * 0.29, height: size * 0.48)
    let connectorRect = CGRect(x: size * 0.455, y: bodyRect.maxY - size * 0.005, width: size * 0.09, height: size * 0.085)
    let sliderRect = CGRect(x: size * 0.34, y: size * 0.69, width: size * 0.32, height: size * 0.17)

    drawGoldShape(in: context, rect: bodyRect, radius: size * 0.06, shadowBlur: size * 0.028)
    drawGoldShape(in: context, rect: connectorRect, radius: size * 0.028, shadowBlur: size * 0.018)
    drawSlider(in: context, rect: sliderRect, size: size)
    drawTeeth(in: context, rect: bodyRect, size: size)
    drawChannel(in: context, rect: bodyRect, size: size)
    drawMonogram(in: context, rect: bodyRect, size: size)
    drawHighlights(in: context, bodyRect: bodyRect, sliderRect: sliderRect, size: size)
}

func drawGoldShape(in context: CGContext, rect: CGRect, radius: CGFloat, shadowBlur: CGFloat) {
    let path = roundedPath(rect, radius: radius)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -rect.height * 0.02), blur: shadowBlur, color: color(0.04, 0.02, 0.0, alpha: 0.42))
    context.addPath(path)
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [
            color(0.96, 0.84, 0.31),
            color(0.90, 0.76, 0.18),
            color(0.64, 0.46, 0.08),
        ],
        locations: [0.0, 0.52, 1.0],
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY)
    )
    context.restoreGState()

    context.addPath(path)
    context.setLineWidth(max(1.0, rect.width * 0.02))
    context.setStrokeColor(color(1.0, 0.96, 0.82, alpha: 0.16))
    context.strokePath()
}

func drawSlider(in context: CGContext, rect: CGRect, size: CGFloat) {
    drawGoldShape(in: context, rect: rect, radius: size * 0.06, shadowBlur: size * 0.028)

    let innerRect = rect.insetBy(dx: rect.width * 0.25, dy: rect.height * 0.23)
    let innerPath = roundedPath(innerRect, radius: size * 0.035)
    context.saveGState()
    context.addPath(innerPath)
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [
            color(0.16, 0.17, 0.19),
            color(0.08, 0.09, 0.10),
        ],
        locations: [0.0, 1.0],
        start: CGPoint(x: innerRect.minX, y: innerRect.maxY),
        end: CGPoint(x: innerRect.maxX, y: innerRect.minY)
    )
    context.restoreGState()

    context.addPath(innerPath)
    context.setLineWidth(size * 0.01)
    context.setStrokeColor(color(1.0, 0.98, 0.84, alpha: 0.14))
    context.strokePath()
}

func drawTeeth(in context: CGContext, rect: CGRect, size: CGFloat) {
    let toothCount = 10
    let segmentHeight = rect.height / CGFloat(toothCount)
    let toothHeight = segmentHeight * 0.42
    let toothWidth = rect.width * 0.18
    let inset = rect.width * 0.08
    let leftX = rect.minX + inset
    let rightX = rect.maxX - inset - toothWidth

    for index in 0..<toothCount {
        let y = rect.maxY - segmentHeight * CGFloat(index + 1) + (segmentHeight - toothHeight) * 0.5
        let toothRect = CGRect(x: leftX, y: y, width: toothWidth, height: toothHeight)
        let mirroredRect = CGRect(x: rightX, y: y, width: toothWidth, height: toothHeight)
        fillTooth(in: context, rect: toothRect, radius: toothHeight * 0.42)
        fillTooth(in: context, rect: mirroredRect, radius: toothHeight * 0.42)
    }
}

func fillTooth(in context: CGContext, rect: CGRect, radius: CGFloat) {
    let path = roundedPath(rect, radius: radius)
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [
            color(0.98, 0.87, 0.36),
            color(0.89, 0.73, 0.16),
            color(0.60, 0.42, 0.06),
        ],
        locations: [0.0, 0.45, 1.0],
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY)
    )
    context.restoreGState()
}

func drawChannel(in context: CGContext, rect: CGRect, size: CGFloat) {
    let channelRect = rect.insetBy(dx: rect.width * 0.31, dy: rect.height * 0.07)
    let channelPath = roundedPath(channelRect, radius: size * 0.03)
    context.saveGState()
    context.addPath(channelPath)
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [
            color(0.18, 0.19, 0.21),
            color(0.08, 0.08, 0.09),
        ],
        locations: [0.0, 1.0],
        start: CGPoint(x: channelRect.minX, y: channelRect.maxY),
        end: CGPoint(x: channelRect.maxX, y: channelRect.minY)
    )
    context.restoreGState()
}

func drawMonogram(in context: CGContext, rect: CGRect, size: CGFloat) {
    let clippedRect = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12)
    let clipPath = roundedPath(clippedRect, radius: size * 0.028)
    let monogram = NSBezierPath()
    monogram.move(to: CGPoint(x: clippedRect.minX + clippedRect.width * 0.12, y: clippedRect.maxY - clippedRect.height * 0.10))
    monogram.line(to: CGPoint(x: clippedRect.maxX - clippedRect.width * 0.12, y: clippedRect.maxY - clippedRect.height * 0.10))
    monogram.line(to: CGPoint(x: clippedRect.minX + clippedRect.width * 0.22, y: clippedRect.midY))
    monogram.line(to: CGPoint(x: clippedRect.maxX - clippedRect.width * 0.12, y: clippedRect.midY))
    monogram.line(to: CGPoint(x: clippedRect.minX + clippedRect.width * 0.12, y: clippedRect.minY + clippedRect.height * 0.10))
    monogram.line(to: CGPoint(x: clippedRect.maxX - clippedRect.width * 0.12, y: clippedRect.minY + clippedRect.height * 0.10))

    context.saveGState()
    context.addPath(clipPath)
    context.clip()
    context.addPath(monogram.cgPath)
    context.setLineWidth(size * 0.06)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(color(0.09, 0.10, 0.11))
    context.strokePath()
    context.restoreGState()
}

func drawHighlights(in context: CGContext, bodyRect: CGRect, sliderRect: CGRect, size: CGFloat) {
    let bodyHighlight = NSBezierPath()
    bodyHighlight.move(to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.14, y: bodyRect.maxY - bodyRect.height * 0.08))
    bodyHighlight.line(to: CGPoint(x: bodyRect.minX + bodyRect.width * 0.14, y: bodyRect.minY + bodyRect.height * 0.08))

    context.addPath(bodyHighlight.cgPath)
    context.setLineWidth(size * 0.012)
    context.setLineCap(.round)
    context.setStrokeColor(color(1.0, 0.98, 0.85, alpha: 0.12))
    context.strokePath()

    let sliderHighlight = NSBezierPath()
    sliderHighlight.move(to: CGPoint(x: sliderRect.minX + sliderRect.width * 0.18, y: sliderRect.maxY - sliderRect.height * 0.18))
    sliderHighlight.line(to: CGPoint(x: sliderRect.maxX - sliderRect.width * 0.28, y: sliderRect.maxY - sliderRect.height * 0.18))
    context.addPath(sliderHighlight.cgPath)
    context.setLineWidth(size * 0.01)
    context.setStrokeColor(color(1.0, 0.98, 0.85, alpha: 0.18))
    context.strokePath()
}

func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPath
}

func drawLinearGradient(in context: CGContext, colors: [CGColor], locations: [CGFloat], start: CGPoint, end: CGPoint) {
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else { return }
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
}

func drawRadialGradient(in context: CGContext, colors: [CGColor], locations: [CGFloat], startCenter: CGPoint, startRadius: CGFloat, endCenter: CGPoint, endRadius: CGFloat) {
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else { return }
    context.drawRadialGradient(gradient, startCenter: startCenter, startRadius: startRadius, endCenter: endCenter, endRadius: endRadius, options: [])
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1.0) -> CGColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha).cgColor
}

func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}
