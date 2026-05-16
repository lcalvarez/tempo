#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

// Renders Tempo's app icon (1024×1024 PNG) as two interlocked rings on the
// dark app background — matches the "you" / "partner" duo motif used in
// DualProgress and PartnerPip throughout the app.

let size: CGFloat = 1024

guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(
        data: nil,
        width: Int(size), height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else { fatalError("ctx") }

// MARK: tokens (sRGB approximations of the theme)

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let bg        = rgb(0.078, 0.082, 0.092)
let bgElev    = rgb(0.114, 0.118, 0.131)
let hairline  = rgb(1, 1, 1, 0.06)
let youColor      = rgb(0.494, 0.722, 0.92)
let partnerColor  = rgb(0.94,  0.78,  0.47)
let accent        = rgb(0.471, 0.851, 0.494)

// MARK: background — soft radial vignette

ctx.setFillColor(bg); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

if let gradient = CGGradient(
    colorsSpace: cs,
    colors: [bgElev, bg] as CFArray,
    locations: [0, 1]
) {
    ctx.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: size * 0.5, y: size * 0.55), startRadius: 0,
        endCenter:   CGPoint(x: size * 0.5, y: size * 0.55), endRadius: size * 0.7,
        options: []
    )
}

// MARK: hairline interior frame — keeps mark crisp at small sizes

let inset: CGFloat = 28
let frameRect = CGRect(x: inset, y: inset, width: size - inset*2, height: size - inset*2)
ctx.setStrokeColor(hairline)
ctx.setLineWidth(2)
ctx.stroke(frameRect)

// MARK: two interlocked rings

let ringStroke: CGFloat = 76
let ringRadius: CGFloat = 252
let gap: CGFloat = ringRadius * 0.92    // how far apart the centers are
let cx = size / 2
let cy = size / 2 - 12                  // nudge slightly up to balance optical weight

let youCenter     = CGPoint(x: cx - gap * 0.5, y: cy)
let partnerCenter = CGPoint(x: cx + gap * 0.5, y: cy)

func strokeRing(at c: CGPoint, color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(ringStroke)
    ctx.setLineCap(.round)
    let rect = CGRect(
        x: c.x - ringRadius, y: c.y - ringRadius,
        width: ringRadius * 2, height: ringRadius * 2
    )
    ctx.strokeEllipse(in: rect)
}

// Soft halo behind each ring
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 80, color: youColor.copy(alpha: 0.35))
strokeRing(at: youCenter, color: youColor)
ctx.restoreGState()

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 80, color: partnerColor.copy(alpha: 0.32))
strokeRing(at: partnerCenter, color: partnerColor)
ctx.restoreGState()

// Re-stroke crisp, no shadow
strokeRing(at: youCenter, color: youColor)
strokeRing(at: partnerCenter, color: partnerColor)

// MARK: weave illusion — clip the partner ring where it crosses behind the you ring's right side

// Create a path of the you-ring stroke band, intersected with the upper crossover region,
// and draw the partner ring color clipped there to give the impression they're linked.
//
// Crossover point is roughly at the top of where the rings meet. We pick a small wedge
// where partner sits behind you, and another wedge where you sits behind partner, to
// produce the classic woven look.

func ringStrokePath(at c: CGPoint) -> CGPath {
    let outer = CGPath(ellipseIn: CGRect(
        x: c.x - ringRadius - ringStroke/2,
        y: c.y - ringRadius - ringStroke/2,
        width: (ringRadius + ringStroke/2) * 2,
        height: (ringRadius + ringStroke/2) * 2
    ), transform: nil)
    let inner = CGPath(ellipseIn: CGRect(
        x: c.x - ringRadius + ringStroke/2,
        y: c.y - ringRadius + ringStroke/2,
        width: (ringRadius - ringStroke/2) * 2,
        height: (ringRadius - ringStroke/2) * 2
    ), transform: nil)
    let band = CGMutablePath()
    band.addPath(outer)
    band.addPath(inner)
    return band
}

// In the *top* crossover, partner appears in front (covers you).
// In the *bottom* crossover, you appears in front (covers partner).
// We've already drawn both rings fully, so we redraw the "in front" segments last.

func clipTopBand(_ above: Bool) {
    let bandHeight: CGFloat = ringRadius * 0.55
    let y0 = above ? cy - bandHeight : cy
    ctx.clip(to: CGRect(x: 0, y: y0, width: size, height: bandHeight))
}

// You-in-front for bottom half: clip to bottom band, restroke you ring.
ctx.saveGState()
clipTopBand(false)
strokeRing(at: youCenter, color: youColor)
ctx.restoreGState()

// Partner-in-front for top half: clip to top band, restroke partner ring.
ctx.saveGState()
clipTopBand(true)
strokeRing(at: partnerCenter, color: partnerColor)
ctx.restoreGState()

// MARK: pulse dot — green accent at the bottom-center, mirrors the "session live" dot

let dotRadius: CGFloat = 26
let dotCenter = CGPoint(x: cx, y: cy + ringRadius + 60)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 60, color: accent.copy(alpha: 0.45))
ctx.setFillColor(accent)
ctx.fillEllipse(in: CGRect(
    x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
    width: dotRadius * 2, height: dotRadius * 2
))
ctx.restoreGState()

// MARK: export

guard let cgImage = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: cgImage)

guard let outArg = CommandLine.arguments.dropFirst().first else {
    fatalError("usage: render-app-icon.swift <output.png>")
}
let outURL = URL(fileURLWithPath: outArg)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try data.write(to: outURL)
print("Wrote \(outURL.path)")
