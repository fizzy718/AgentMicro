#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("Usage: render_agentmicro_dmg_background.swift <output.png>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 660
let height = 400

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    FileHandle.standardError.write(Data("Unable to create DMG background bitmap.\n".utf8))
    exit(1)
}

bitmap.size = NSSize(width: width, height: height)
let previousContext = NSGraphicsContext.current
NSGraphicsContext.current = context

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(
    starting: NSColor(calibratedRed: 0.965, green: 0.975, blue: 0.995, alpha: 1),
    ending: NSColor(calibratedRed: 0.855, green: 0.895, blue: 0.975, alpha: 1))?
    .draw(in: canvas, angle: -90)

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center
("Drag AgentMicro to Applications" as NSString).draw(
    in: NSRect(x: 60, y: 318, width: 540, height: 38),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 0.92),
        .paragraphStyle: titleStyle,
    ])

("Install by dragging the app onto the Applications folder." as NSString).draw(
    in: NSRect(x: 80, y: 292, width: 500, height: 24),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.26, alpha: 0.76),
        .paragraphStyle: titleStyle,
    ])

let arrowColor = NSColor(calibratedRed: 0.20, green: 0.39, blue: 0.76, alpha: 0.78)
arrowColor.setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 270, y: 180))
arrow.line(to: NSPoint(x: 390, y: 180))
arrow.move(to: NSPoint(x: 368, y: 198))
arrow.line(to: NSPoint(x: 390, y: 180))
arrow.line(to: NSPoint(x: 368, y: 162))
arrow.stroke()

let lightColors = [
    NSColor(calibratedRed: 0.61, green: 0.83, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.61, green: 0.95, blue: 0.59, alpha: 1),
    NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.72, alpha: 1),
    NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.45, alpha: 1),
    NSColor(calibratedWhite: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.61, green: 0.83, blue: 1.00, alpha: 1),
]
let lightWidth: CGFloat = 24
let lightHeight: CGFloat = 8
let lightGap: CGFloat = 7
let totalLightWidth = (lightWidth * 3) + (lightGap * 2)
let lightsOriginX = (CGFloat(width) - totalLightWidth) / 2
for (index, color) in lightColors.enumerated() {
    let column = index % 3
    let row = index / 3
    let rect = NSRect(
        x: lightsOriginX + CGFloat(column) * (lightWidth + lightGap),
        y: 42 + CGFloat(1 - row) * (lightHeight + lightGap),
        width: lightWidth,
        height: lightHeight)
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
}

context.flushGraphics()
NSGraphicsContext.current = previousContext

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Unable to encode DMG background PNG.\n".utf8))
    exit(1)
}
try data.write(to: outputURL, options: .atomic)
