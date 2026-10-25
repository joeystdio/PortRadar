import AppKit
import CoreGraphics

let iconsetPath = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func renderIcon(size: Int) -> NSImage {
    let cgSize = CGSize(width: size, height: size)
    let image = NSImage(size: cgSize)
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    let s = CGFloat(size)
    let padding = s * 0.08
    let rect = CGRect(x: padding, y: padding, width: s - padding * 2, height: s - padding * 2)
    let cornerRadius = rect.width * 0.225
    
    // Outer shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.025), blur: s * 0.05, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.14, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Clip to squircle
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    
    // Deep radar background gradient (Dark Navy -> Deep Teal -> Electric Cyan)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.12, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.04, green: 0.18, blue: 0.32, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.06, green: 0.55, blue: 0.72, alpha: 1.0).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.6, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY),
            options: []
        )
    }
    
    let center = CGPoint(x: s * 0.5, y: s * 0.5)
    
    // Radar sweep sector glow (top-right quadrant)
    ctx.saveGState()
    ctx.move(to: center)
    ctx.addArc(center: center, radius: s * 0.36, startAngle: 0.15, endAngle: 1.25, clockwise: false)
    ctx.closePath()
    ctx.setFillColor(NSColor(calibratedRed: 0.13, green: 0.90, blue: 0.65, alpha: 0.24).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Concentric radar rings
    for (idx, mult) in [0.14, 0.25, 0.35].enumerated() {
        let r = s * CGFloat(mult)
        let ringRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.20, green: 0.92, blue: 0.98, alpha: 0.42 - CGFloat(idx) * 0.1).cgColor)
        ctx.setLineWidth(max(1.5, s * 0.015))
        ctx.strokeEllipse(in: ringRect)
    }
    
    // Crosshair axes
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
    ctx.setLineWidth(max(1.0, s * 0.01))
    ctx.move(to: CGPoint(x: center.x - s * 0.36, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x + s * 0.36, y: center.y))
    ctx.move(to: CGPoint(x: center.x, y: center.y - s * 0.36))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y + s * 0.36))
    ctx.strokePath()
    
    // Radar sweep line
    let angle: CGFloat = 0.72
    let sweepEnd = CGPoint(x: center.x + cos(angle) * s * 0.35, y: center.y + sin(angle) * s * 0.35)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.20, green: 0.98, blue: 0.72, alpha: 0.95).cgColor)
    ctx.setLineWidth(max(2.0, s * 0.024))
    ctx.setLineCap(.round)
    ctx.move(to: center)
    ctx.addLine(to: sweepEnd)
    ctx.strokePath()
    
    // Glowing port blips on the radar
    let blips: [(CGFloat, CGFloat, NSColor)] = [
        (0.16, 0.14, NSColor(calibratedRed: 0.20, green: 0.98, blue: 0.65, alpha: 1.0)),
        (-0.18, 0.12, NSColor(calibratedRed: 0.13, green: 0.83, blue: 0.93, alpha: 1.0)),
        (0.11, -0.20, NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.20, alpha: 1.0))
    ]
    for (dx, dy, color) in blips {
        let pt = CGPoint(x: center.x + dx * s, y: center.y + dy * s)
        let r = s * 0.032
        ctx.setFillColor(color.withAlphaComponent(0.32).cgColor)
        ctx.fillEllipse(in: CGRect(x: pt.x - r * 1.9, y: pt.y - r * 1.9, width: r * 3.8, height: r * 3.8))
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
    }
    
    // Center core node
    let coreR = s * 0.048
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2))
    
    // Inner glass border
    ctx.addPath(bgPath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.setLineWidth(max(1.5, s * 0.018))
    ctx.strokePath()
    
    ctx.restoreGState()
    image.unlockFocus()
    return image
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, name) in sizes {
    let img = renderIcon(size: px)
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
    }
}
print("Generated PortRadar iconset successfully.")
