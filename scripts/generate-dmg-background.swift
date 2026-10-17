import AppKit

func generateDMGBackground(scale: CGFloat, outputPath: String, projectDir: String) {
    let width: CGFloat = 660
    let height: CGFloat = 380

    let pixelWidth = Int(width * scale)
    let pixelHeight = Int(height * scale)

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        fatalError("Failed to create CGContext")
    }

    // Set scale for Retina
    context.scaleBy(x: scale, y: scale)

    // Flip coordinates to standard macOS top-left origin: (0,0) is top-left
    context.translateBy(x: 0, y: height)
    context.scaleBy(x: 1.0, y: -1.0)

    // Clean pure white background
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // 1. Draw Centered Brand Header: Pluck Logo + "Pluck" Wordmark
    let logoHeight: CGFloat = 26
    let logoPath = "\(projectDir)/assest/balck-logo.png"
    if let logoImage = NSImage(contentsOfFile: logoPath),
       let cgLogo = logoImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let logoAspect = CGFloat(cgLogo.width) / CGFloat(cgLogo.height)
        let logoWidth = logoHeight * logoAspect

        let font = NSFont.systemFont(ofSize: 22, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(white: 0.08, alpha: 1.0),
            .kern: -0.4
        ]
        let attrString = NSAttributedString(string: "Pluck", attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let startX: CGFloat = 40
        let logoY: CGFloat = 30

        let logoRect = CGRect(x: startX, y: logoY, width: logoWidth, height: logoHeight)
        context.saveGState()
        context.translateBy(x: logoRect.minX, y: logoRect.maxY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.interpolationQuality = .high
        context.draw(cgLogo, in: CGRect(x: 0, y: 0, width: logoRect.width, height: logoRect.height))
        context.restoreGState()

        context.saveGState()
        context.translateBy(x: logoRect.maxX + 10, y: logoY + 20)
        context.scaleBy(x: 1.0, y: -1.0)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // 2. Draw Center Arrow: pointing right, perfectly centered with the 128px icons at Y = 200
    let arrowCenterX: CGFloat = 330
    let arrowCenterY: CGFloat = 200
    let arrowLength: CGFloat = 46
    let wingLength: CGFloat = 14
    let wingAngle: CGFloat = 40.0 * .pi / 180.0 // 40 degrees

    let startX = arrowCenterX - (arrowLength / 2)
    let tipX = arrowCenterX + (arrowLength / 2)

    context.setStrokeColor(NSColor(white: 0.12, alpha: 1.0).cgColor)
    context.setLineWidth(3.5)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: startX, y: arrowCenterY))
    arrowPath.addLine(to: CGPoint(x: tipX, y: arrowCenterY))

    let topWingX = tipX - (wingLength * cos(wingAngle))
    let topWingY = arrowCenterY - (wingLength * sin(wingAngle))
    arrowPath.move(to: CGPoint(x: topWingX, y: topWingY))
    arrowPath.addLine(to: CGPoint(x: tipX, y: arrowCenterY))

    let botWingX = tipX - (wingLength * cos(wingAngle))
    let botWingY = arrowCenterY + (wingLength * sin(wingAngle))
    arrowPath.addLine(to: CGPoint(x: botWingX, y: botWingY))

    context.addPath(arrowPath)
    context.strokePath()

    guard let cgImage = context.makeImage() else {
        fatalError("Failed to create CGImage")
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: width, height: height)
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }

    try? pngData.write(to: URL(fileURLWithPath: outputPath))
}

let args = CommandLine.arguments
let projectDir = args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath
let outputDir = args.count > 2 ? args[2] : "\(projectDir)/build/dmg-assets"

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

generateDMGBackground(scale: 1.0, outputPath: "\(outputDir)/dmg_background.png", projectDir: projectDir)
generateDMGBackground(scale: 2.0, outputPath: "\(outputDir)/dmg_background@2x.png", projectDir: projectDir)
print("DMG background generated in \(outputDir)")
