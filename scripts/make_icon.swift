// Generates the 1024x1024 app icon with CoreGraphics (runs on macOS: `swift scripts/make_icon.swift <out.png>`).
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create context")
}

let colors = [CGColor(red: 0.36, green: 0.27, blue: 0.95, alpha: 1),
              CGColor(red: 0.12, green: 0.75, blue: 0.86, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

// Clipboard board
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
ctx.addPath(CGPath(roundedRect: CGRect(x: 262, y: 170, width: 500, height: 640), cornerWidth: 70, cornerHeight: 70, transform: nil))
ctx.fillPath()

// Clip
ctx.setFillColor(CGColor(red: 0.20, green: 0.16, blue: 0.55, alpha: 1))
ctx.addPath(CGPath(roundedRect: CGRect(x: 392, y: 740, width: 240, height: 120), cornerWidth: 40, cornerHeight: 40, transform: nil))
ctx.fillPath()

// Text lines
ctx.setFillColor(CGColor(red: 0.36, green: 0.27, blue: 0.95, alpha: 0.85))
let widths: [CGFloat] = [380, 300, 340, 220]
for (i, w) in widths.enumerated() {
    let y = CGFloat(620 - i * 110)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 322, y: y, width: w, height: 44), cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.fillPath()
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create image")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Could not write \(out)") }
print("Wrote \(out)")
