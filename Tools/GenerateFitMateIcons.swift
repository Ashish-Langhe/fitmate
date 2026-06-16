import AppKit

let outputDirectory = URL(fileURLWithPath: "fitmate/Assets.xcassets/AppIcon.appiconset")
let sizes: [(String, Int)] = [
    ("AppIcon-20@2x.png", 40),
    ("AppIcon-20@3x.png", 60),
    ("AppIcon-29@2x.png", 58),
    ("AppIcon-29@3x.png", 87),
    ("AppIcon-40@2x.png", 80),
    ("AppIcon-40@3x.png", 120),
    ("AppIcon-60@2x.png", 120),
    ("AppIcon-60@3x.png", 180),
    ("AppIcon-76@2x.png", 152),
    ("AppIcon-83.5@2x.png", 167),
    ("AppIcon-1024.png", 1024)
]

func drawIcon(size: Int) -> NSImage {
    let canvas = NSSize(width: size, height: size)
    let image = NSImage(size: canvas)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: canvas)
    let background = NSGradient(colors: [
        NSColor(red: 0.00, green: 0.70, blue: 0.42, alpha: 1),
        NSColor(red: 0.00, green: 0.48, blue: 0.88, alpha: 1)
    ])!
    background.draw(in: rect, angle: 45)

    let inset = CGFloat(size) * 0.15
    let ringRect = rect.insetBy(dx: inset, dy: inset)
    let ringPath = NSBezierPath(ovalIn: ringRect)
    NSColor.white.withAlphaComponent(0.24).setStroke()
    ringPath.lineWidth = CGFloat(size) * 0.06
    ringPath.stroke()

    let boltPath = NSBezierPath()
    let w = CGFloat(size)
    boltPath.move(to: CGPoint(x: w * 0.55, y: w * 0.82))
    boltPath.line(to: CGPoint(x: w * 0.31, y: w * 0.47))
    boltPath.line(to: CGPoint(x: w * 0.49, y: w * 0.47))
    boltPath.line(to: CGPoint(x: w * 0.42, y: w * 0.17))
    boltPath.line(to: CGPoint(x: w * 0.70, y: w * 0.56))
    boltPath.line(to: CGPoint(x: w * 0.51, y: w * 0.56))
    boltPath.close()
    NSColor.white.setFill()
    boltPath.fill()

    let heartPath = NSBezierPath()
    heartPath.move(to: CGPoint(x: w * 0.64, y: w * 0.34))
    heartPath.curve(to: CGPoint(x: w * 0.76, y: w * 0.46), controlPoint1: CGPoint(x: w * 0.78, y: w * 0.38), controlPoint2: CGPoint(x: w * 0.82, y: w * 0.50))
    heartPath.curve(to: CGPoint(x: w * 0.64, y: w * 0.28), controlPoint1: CGPoint(x: w * 0.71, y: w * 0.40), controlPoint2: CGPoint(x: w * 0.66, y: w * 0.34))
    heartPath.curve(to: CGPoint(x: w * 0.52, y: w * 0.46), controlPoint1: CGPoint(x: w * 0.62, y: w * 0.34), controlPoint2: CGPoint(x: w * 0.55, y: w * 0.40))
    heartPath.curve(to: CGPoint(x: w * 0.64, y: w * 0.34), controlPoint1: CGPoint(x: w * 0.46, y: w * 0.50), controlPoint2: CGPoint(x: w * 0.50, y: w * 0.38))
    heartPath.close()
    NSColor(red: 1.0, green: 0.22, blue: 0.28, alpha: 1).setFill()
    heartPath.fill()

    image.unlockFocus()
    return image
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for (name, size) in sizes {
    let image = drawIcon(size: size)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(name)")
    }

    try png.write(to: outputDirectory.appendingPathComponent(name))
}
