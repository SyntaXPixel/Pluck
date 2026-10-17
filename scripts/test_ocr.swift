import AppKit
import Foundation
import Vision

// 1. Create a bitmap image with text
let width = 400
let height = 100
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create CGContext")
    exit(1)
}

context.setFillColor(NSColor.white.cgColor)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = graphicsContext

let text: NSString = "Pluck extracts unselectable text instantly."
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .bold),
    .foregroundColor: NSColor.black
]
text.draw(at: NSPoint(x: 20, y: 40), withAttributes: attributes)

guard let cgImage = context.makeImage() else {
    print("Failed to make CGImage")
    exit(1)
}

print("Created test image: \(cgImage.width)x\(cgImage.height)")

// 2. Run Vision OCR
let startTime = CFAbsoluteTimeGetCurrent()
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.automaticallyDetectsLanguage = true

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([request])
    let duration = CFAbsoluteTimeGetCurrent() - startTime
    print("OCR completed in \(String(format: "%.3f", duration))s")

    guard let results = request.results, !results.isEmpty else {
        print("No results returned!")
        exit(0)
    }

    for observation in results {
        if let candidate = observation.topCandidates(1).first {
            print("Recognized: \(candidate.string)")
        }
    }
} catch {
    print("OCR failed with error: \(error)")
}
