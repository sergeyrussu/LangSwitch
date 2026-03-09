import AppKit

final class FlagStore {
    private var cache: [String: NSImage] = [:]
    private let exactSourceMap: [String: String] = [
        "com.apple.keylayout.abc": "US",
        "com.apple.keylayout.us": "US",
        "com.apple.keylayout.british": "GB",
        "com.apple.keylayout.australian": "AU",
        "com.apple.keylayout.newzealand": "NZ",
        "com.apple.keylayout.russian": "RU",
        "com.apple.keylayout.russianwin": "RU",
        "com.apple.keylayout.ukrainian": "UA",
        "com.apple.keylayout.german": "DE",
        "com.apple.keylayout.french": "FR",
        "com.apple.keylayout.spanish": "ES",
        "com.apple.keylayout.italian": "IT",
        "com.apple.keylayout.turkish": "TR",
        "com.apple.keylayout.hindi": "IN"
    ]

    func image(for state: AppDelegate.InputSourceState) -> NSImage {
        let country = mappedCountryCode(sourceID: state.sourceID, languageCode: state.languageCode)
        if let cached = cache[country] {
            return cached
        }

        let image = FlagImageFactory.flag(for: country)
        cache[country] = image
        return image
    }

    private func mappedCountryCode(sourceID: String, languageCode: String) -> String {
        let source = sourceID.lowercased()

        if let exact = exactSourceMap[source] {
            return exact
        }

        if source.contains("russian") { return "RU" }
        if source.contains("hindi") || source.contains("devanagari") { return "IN" }
        if source.contains("pinyin") || source.contains("chinese") || source.contains("scim") { return "CN" }
        if source.contains("kotoeri") || source.contains("japanese") { return "JP" }
        if source.contains("korean") { return "KR" }
        if source.contains("ukrainian") { return "UA" }
        if source.contains("german") { return "DE" }
        if source.contains("french") { return "FR" }
        if source.contains("spanish") { return "ES" }
        if source.contains("italian") { return "IT" }
        if source.contains("arabic") { return "SA" }
        if source.contains("turkish") { return "TR" }
        if source.contains("abc") { return "US" }

        switch languageCode.lowercased() {
        case "ru": return "RU"
        case "hi": return "IN"
        case "zh": return "CN"
        case "ja": return "JP"
        case "ko": return "KR"
        case "uk": return "UA"
        case "de": return "DE"
        case "fr": return "FR"
        case "es": return "ES"
        case "it": return "IT"
        case "ar": return "SA"
        case "tr": return "TR"
        default: return "UNKNOWN"
        }
    }
}

private enum FlagImageFactory {
    static func flag(for countryCode: String, size: NSSize = NSSize(width: 22, height: 14)) -> NSImage {
        switch countryCode {
        case "AU": return australia(size: size)
        case "GB": return unitedKingdom(size: size)
        case "NZ": return newZealand(size: size)
        case "RU": return russia(size: size)
        case "US": return usa(size: size)
        case "IN": return india(size: size)
        case "CN": return china(size: size)
        case "JP": return japan(size: size)
        case "KR": return korea(size: size)
        case "UA": return ukraine(size: size)
        case "DE": return germany(size: size)
        case "FR": return france(size: size)
        case "ES": return spain(size: size)
        case "IT": return italy(size: size)
        case "SA": return saudi(size: size)
        case "TR": return turkey(size: size)
        default: return unknown(size: size)
        }
    }

    private static func russia(size: NSSize) -> NSImage {
        stripe3(size: size, top: .white, mid: .systemBlue, bottom: .systemRed)
    }

    private static func unitedKingdom(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        drawUnionJack(in: NSRect(origin: .zero, size: size))
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func australia(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.53, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let canton = NSRect(x: 0, y: size.height * 0.5, width: size.width * 0.5, height: size.height * 0.5)
        drawUnionJack(in: canton)

        let starAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 4.5), .foregroundColor: NSColor.white]
        NSAttributedString(string: "★", attributes: starAttrs).draw(at: NSPoint(x: size.width * 0.66, y: size.height * 0.63))
        NSAttributedString(string: "★", attributes: starAttrs).draw(at: NSPoint(x: size.width * 0.76, y: size.height * 0.42))
        NSAttributedString(string: "★", attributes: starAttrs).draw(at: NSPoint(x: size.width * 0.58, y: size.height * 0.30))
        NSAttributedString(string: "★", attributes: starAttrs).draw(at: NSPoint(x: size.width * 0.72, y: size.height * 0.16))

        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func newZealand(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.53, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let canton = NSRect(x: 0, y: size.height * 0.5, width: size.width * 0.5, height: size.height * 0.5)
        drawUnionJack(in: canton)

        let redStarAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 4.5), .foregroundColor: NSColor.systemRed]
        NSAttributedString(string: "★", attributes: redStarAttrs).draw(at: NSPoint(x: size.width * 0.68, y: size.height * 0.60))
        NSAttributedString(string: "★", attributes: redStarAttrs).draw(at: NSPoint(x: size.width * 0.79, y: size.height * 0.44))
        NSAttributedString(string: "★", attributes: redStarAttrs).draw(at: NSPoint(x: size.width * 0.71, y: size.height * 0.27))
        NSAttributedString(string: "★", attributes: redStarAttrs).draw(at: NSPoint(x: size.width * 0.84, y: size.height * 0.16))

        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func usa(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let stripeHeight = size.height / 13
        for i in 0..<13 {
            (i.isMultiple(of: 2) ? NSColor.systemRed : NSColor.white).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: CGFloat(i) * stripeHeight, width: size.width, height: stripeHeight)).fill()
        }
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size.height - stripeHeight * 7, width: size.width * 0.45, height: stripeHeight * 7)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func india(size: NSSize) -> NSImage {
        let image = stripe3(size: size, top: .systemOrange, mid: .white, bottom: .systemGreen)
        image.lockFocus()
        NSColor.systemBlue.setStroke()
        let d = min(size.width, size.height) * 0.34
        let r = NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)
        let chakra = NSBezierPath(ovalIn: r)
        chakra.lineWidth = 1
        chakra.stroke()
        image.unlockFocus()
        return image
    }

    private static func china(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 6), .foregroundColor: NSColor.systemYellow]
        NSAttributedString(string: "★", attributes: attrs).draw(at: NSPoint(x: 3, y: 5))
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func japan(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.systemRed.setFill()
        let d = min(size.width, size.height) * 0.48
        NSBezierPath(ovalIn: NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func korea(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.systemRed.setFill()
        let d = min(size.width, size.height) * 0.42
        NSBezierPath(ovalIn: NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2, width: d, height: d)).fill()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: (size.width - d) / 2, y: (size.height - d) / 2 - d * 0.2, width: d, height: d * 0.5)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func ukraine(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2)).fill()
        NSColor.systemYellow.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: size.height / 2)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func germany(size: NSSize) -> NSImage { stripe3(size: size, top: .black, mid: .systemRed, bottom: .systemYellow) }

    private static func france(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let w = size.width / 3
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: size.height)).fill()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: w, y: 0, width: w, height: size.height)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: w * 2, y: 0, width: w, height: size.height)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func spain(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let small = size.height * 0.25
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: size.height - small, width: size.width, height: small)).fill()
        NSColor.systemYellow.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: small, width: size.width, height: size.height - small * 2)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: small)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func italy(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let w = size.width / 3
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: w, height: size.height)).fill()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: w, y: 0, width: w, height: size.height)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: w * 2, y: 0, width: w, height: size.height)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func saudi(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: 1.5)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func turkey(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.white.setFill()
        let d = min(size.width, size.height) * 0.44
        NSBezierPath(ovalIn: NSRect(x: size.width * 0.25, y: (size.height - d) / 2, width: d, height: d)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: size.width * 0.31, y: (size.height - d * 0.8) / 2, width: d * 0.8, height: d * 0.8)).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 4), .foregroundColor: NSColor.white]
        NSAttributedString(string: "★", attributes: attrs).draw(at: NSPoint(x: size.width * 0.56, y: size.height * 0.38))
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func stripe3(size: NSSize, top: NSColor, mid: NSColor, bottom: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let h = size.height / 3
        top.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: h * 2, width: size.width, height: h)).fill()
        mid.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: h, width: size.width, height: h)).fill()
        bottom.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: h)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func drawUnionJack(in rect: NSRect) {
        NSColor(calibratedRed: 0.05, green: 0.18, blue: 0.50, alpha: 1).setFill()
        NSBezierPath(rect: rect).fill()

        NSColor.white.setStroke()
        let whiteDiagonal1 = NSBezierPath()
        whiteDiagonal1.move(to: NSPoint(x: rect.minX, y: rect.minY))
        whiteDiagonal1.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        whiteDiagonal1.lineWidth = max(1.2, rect.height * 0.22)
        whiteDiagonal1.stroke()

        let whiteDiagonal2 = NSBezierPath()
        whiteDiagonal2.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        whiteDiagonal2.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        whiteDiagonal2.lineWidth = max(1.2, rect.height * 0.22)
        whiteDiagonal2.stroke()

        NSColor.systemRed.setStroke()
        whiteDiagonal1.lineWidth = max(0.8, rect.height * 0.10)
        whiteDiagonal1.stroke()
        whiteDiagonal2.lineWidth = max(0.8, rect.height * 0.10)
        whiteDiagonal2.stroke()

        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: rect.minX, y: rect.midY - rect.height * 0.10, width: rect.width, height: rect.height * 0.20)).fill()
        NSBezierPath(rect: NSRect(x: rect.midX - rect.width * 0.10, y: rect.minY, width: rect.width * 0.20, height: rect.height)).fill()

        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: rect.minX, y: rect.midY - rect.height * 0.06, width: rect.width, height: rect.height * 0.12)).fill()
        NSBezierPath(rect: NSRect(x: rect.midX - rect.width * 0.06, y: rect.minY, width: rect.width * 0.12, height: rect.height)).fill()
    }

    private static func border(size: NSSize) {
        NSColor.black.withAlphaComponent(0.25).setStroke()
        let p = NSBezierPath(rect: NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
        p.lineWidth = 1
        p.stroke()
    }

    private static func unknown(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        border(size: size)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
