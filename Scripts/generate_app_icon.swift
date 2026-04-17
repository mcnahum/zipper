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

private struct PartPalette {
    let top: CGColor
    let bottom: CGColor
    let line: CGColor
    let badge: CGColor
    let badgeText: NSColor
}

private struct PartLayout {
    let center: CGPoint
    let size: CGSize
    let rotationDegrees: CGFloat
    let palette: PartPalette
    let partNumber: String
    let isFront: Bool
}

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

let previewURL = designURL.appendingPathComponent("powerunrar-logo-preview.png")
let masterURL = designURL.appendingPathComponent("powerunrar-logo-master.png")

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
    let outerInset = size * 0.045
    let outerRect = canvas.insetBy(dx: outerInset, dy: outerInset)
    let outerRadius = size * 0.22
    let outerPath = roundedPath(outerRect, radius: outerRadius)

    context.clear(canvas)
    context.saveGState()
    context.addPath(outerPath)
    context.clip()

    drawLinearGradient(
        in: context,
        colors: [
            color(0.22, 0.23, 0.26),
            color(0.10, 0.11, 0.13),
            color(0.05, 0.05, 0.06),
        ],
        locations: [0.0, 0.48, 1.0],
        start: CGPoint(x: outerRect.minX, y: outerRect.maxY),
        end: CGPoint(x: outerRect.maxX, y: outerRect.minY)
    )

    drawRadialGradient(
        in: context,
        colors: [
            color(0.95, 0.42, 0.18, alpha: 0.28),
            color(0.95, 0.42, 0.18, alpha: 0.0),
        ],
        locations: [0.0, 1.0],
        startCenter: CGPoint(x: outerRect.midX, y: outerRect.midY + size * 0.05),
        startRadius: size * 0.01,
        endCenter: CGPoint(x: outerRect.midX, y: outerRect.midY + size * 0.05),
        endRadius: size * 0.34
    )

    drawRadialGradient(
        in: context,
        colors: [
            color(1.0, 1.0, 1.0, alpha: 0.10),
            color(1.0, 1.0, 1.0, alpha: 0.0),
        ],
        locations: [0.0, 1.0],
        startCenter: CGPoint(x: outerRect.minX + outerRect.width * 0.26, y: outerRect.maxY),
        startRadius: size * 0.01,
        endCenter: CGPoint(x: outerRect.minX + outerRect.width * 0.26, y: outerRect.maxY),
        endRadius: size * 0.42
    )

    context.restoreGState()

    context.addPath(outerPath)
    context.setLineWidth(size * 0.01)
    context.setStrokeColor(color(1.0, 1.0, 1.0, alpha: 0.10))
    context.strokePath()

    let backPalette = PartPalette(
        top: color(0.73, 0.35, 0.18),
        bottom: color(0.50, 0.18, 0.08),
        line: color(1.0, 0.88, 0.72, alpha: 0.18),
        badge: color(0.18, 0.18, 0.20),
        badgeText: NSColor(calibratedWhite: 0.96, alpha: 1.0)
    )
    let middlePalette = PartPalette(
        top: color(0.97, 0.65, 0.23),
        bottom: color(0.78, 0.38, 0.10),
        line: color(1.0, 0.94, 0.78, alpha: 0.18),
        badge: color(0.20, 0.20, 0.22),
        badgeText: NSColor(calibratedWhite: 0.97, alpha: 1.0)
    )
    let frontPalette = PartPalette(
        top: color(1.0, 0.88, 0.28),
        bottom: color(0.88, 0.60, 0.08),
        line: color(1.0, 0.98, 0.82, alpha: 0.22),
        badge: color(0.17, 0.18, 0.20),
        badgeText: NSColor(calibratedWhite: 0.98, alpha: 1.0)
    )

    let parts = [
        PartLayout(
            center: CGPoint(x: size * 0.38, y: size * 0.50),
            size: CGSize(width: size * 0.27, height: size * 0.46),
            rotationDegrees: -18,
            palette: backPalette,
            partNumber: "01",
            isFront: false
        ),
        PartLayout(
            center: CGPoint(x: size * 0.63, y: size * 0.51),
            size: CGSize(width: size * 0.27, height: size * 0.46),
            rotationDegrees: 16,
            palette: middlePalette,
            partNumber: "02",
            isFront: false
        ),
        PartLayout(
            center: CGPoint(x: size * 0.50, y: size * 0.47),
            size: CGSize(width: size * 0.31, height: size * 0.52),
            rotationDegrees: 0,
            palette: frontPalette,
            partNumber: "03",
            isFront: true
        ),
    ]

    for part in parts {
        drawArchivePart(in: context, part: part, iconSize: size)
    }

}

private func drawArchivePart(in context: CGContext, part: PartLayout, iconSize: CGFloat) {
    context.saveGState()
    context.translateBy(x: part.center.x, y: part.center.y)
    context.rotate(by: part.rotationDegrees * .pi / 180)

    let bodyRect = CGRect(
        x: -part.size.width / 2,
        y: -part.size.height / 2,
        width: part.size.width,
        height: part.size.height
    )
    let bodyRadius = part.size.width * 0.18
    let bodyPath = roundedPath(bodyRect, radius: bodyRadius)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -iconSize * 0.014), blur: iconSize * 0.035, color: color(0.0, 0.0, 0.0, alpha: 0.33))
    context.addPath(bodyPath)
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [part.palette.top, part.palette.bottom],
        locations: [0.0, 1.0],
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY)
    )
    context.restoreGState()

    context.addPath(bodyPath)
    context.setLineWidth(max(1.0, part.size.width * 0.028))
    context.setStrokeColor(part.palette.line)
    context.strokePath()

    let handleRect = CGRect(
        x: -part.size.width * 0.16,
        y: bodyRect.maxY - part.size.height * 0.03,
        width: part.size.width * 0.32,
        height: part.size.height * 0.12
    )
    let handlePath = roundedPath(handleRect, radius: handleRect.height / 2)
    context.addPath(handlePath)
    context.setFillColor(color(1.0, 0.98, 0.86, alpha: 0.22))
    context.fillPath()

    let panelRect = CGRect(
        x: bodyRect.minX + part.size.width * 0.16,
        y: bodyRect.minY + part.size.height * 0.14,
        width: part.size.width * 0.68,
        height: part.size.height * 0.56
    )
    let panelPath = roundedPath(panelRect, radius: part.size.width * 0.10)
    context.addPath(panelPath)
    context.clip()
    drawLinearGradient(
        in: context,
        colors: [
            color(0.17, 0.18, 0.20),
            color(0.08, 0.09, 0.10)
        ],
        locations: [0.0, 1.0],
        start: CGPoint(x: panelRect.minX, y: panelRect.maxY),
        end: CGPoint(x: panelRect.maxX, y: panelRect.minY)
    )
    context.resetClip()

    context.addPath(panelPath)
    context.setLineWidth(max(1.0, part.size.width * 0.018))
    context.setStrokeColor(color(1.0, 1.0, 1.0, alpha: 0.08))
    context.strokePath()

    drawSideRidges(in: context, bodyRect: bodyRect, iconSize: iconSize)

    let badgeRect = CGRect(
        x: bodyRect.minX + part.size.width * 0.13,
        y: bodyRect.maxY - part.size.height * 0.20,
        width: part.size.width * 0.30,
        height: part.size.height * 0.12
    )
    let badgePath = roundedPath(badgeRect, radius: badgeRect.height / 2)
    context.addPath(badgePath)
    context.setFillColor(part.palette.badge)
    context.fillPath()

    drawText(
        part.partNumber,
        in: badgeRect.offsetBy(dx: 0, dy: badgeRect.height * 0.03),
        fontSize: max(iconSize * 0.038, 9),
        weight: .bold,
        color: part.palette.badgeText,
        alignment: .center
    )

    if part.isFront {
        let rarRect = CGRect(
            x: panelRect.minX,
            y: panelRect.midY - part.size.height * 0.12,
            width: panelRect.width,
            height: part.size.height * 0.24
        )
        drawText(
            "RAR",
            in: rarRect,
            fontSize: iconSize * 0.088,
            weight: .black,
            color: NSColor(calibratedWhite: 0.97, alpha: 0.96),
            alignment: .center
        )

        let partCaptionRect = CGRect(
            x: panelRect.minX,
            y: panelRect.minY + part.size.height * 0.04,
            width: panelRect.width,
            height: part.size.height * 0.09
        )
        drawText(
            "PART 03",
            in: partCaptionRect,
            fontSize: iconSize * 0.033,
            weight: .semibold,
            color: NSColor(calibratedWhite: 0.88, alpha: 0.82),
            alignment: .center
        )
    }

    context.restoreGState()
}

func drawSideRidges(in context: CGContext, bodyRect: CGRect, iconSize: CGFloat) {
    let ridgeCount = 6
    let ridgeWidth = bodyRect.width * 0.13
    let ridgeHeight = bodyRect.height * 0.04
    let leftX = bodyRect.minX + bodyRect.width * 0.07
    let rightX = bodyRect.maxX - bodyRect.width * 0.07 - ridgeWidth

    for index in 0..<ridgeCount {
        let y = bodyRect.minY + bodyRect.height * 0.18 + CGFloat(index) * bodyRect.height * 0.10
        let leftRect = CGRect(x: leftX, y: y, width: ridgeWidth, height: ridgeHeight)
        let rightRect = CGRect(x: rightX, y: y, width: ridgeWidth, height: ridgeHeight)

        for rect in [leftRect, rightRect] {
            let path = roundedPath(rect, radius: ridgeHeight / 2)
            context.addPath(path)
            context.setFillColor(color(1.0, 0.97, 0.85, alpha: 0.22))
            context.fillPath()
        }
    }

    let shineRect = CGRect(
        x: bodyRect.minX + bodyRect.width * 0.18,
        y: bodyRect.maxY - bodyRect.height * 0.16,
        width: bodyRect.width * 0.52,
        height: max(iconSize * 0.010, 1.0)
    )
    let shinePath = roundedPath(shineRect, radius: shineRect.height / 2)
    context.addPath(shinePath)
    context.setFillColor(color(1.0, 1.0, 1.0, alpha: 0.25))
    context.fillPath()
}

func drawText(
    _ text: String,
    in rect: CGRect,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    alignment: NSTextAlignment
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: -fontSize * 0.03
    ]

    let attributedString = NSAttributedString(string: text, attributes: attributes)
    attributedString.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
}

func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawLinearGradient(
    in context: CGContext,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    let cgGradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
    context.drawLinearGradient(cgGradient, start: start, end: end, options: [])
}

func drawRadialGradient(
    in context: CGContext,
    colors: [CGColor],
    locations: [CGFloat],
    startCenter: CGPoint,
    startRadius: CGFloat,
    endCenter: CGPoint,
    endRadius: CGFloat
) {
    let cgGradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
    context.drawRadialGradient(
        cgGradient,
        startCenter: startCenter,
        startRadius: startRadius,
        endCenter: endCenter,
        endRadius: endRadius,
        options: []
    )
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1.0) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}
