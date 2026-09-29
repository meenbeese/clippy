//
//  AgentConverter.swift
//  Clippy
//
//  Converts a decompiled `*.acs` agent folder into a `.agent` bundle that
//  `Agent` can read, replacing the former `agent-convert.sh`.
//
//  The script needed ImageMagick, ffmpeg and iconv. All three steps are done
//  natively here: Core Graphics keys the background and assembles the sprite
//  map, AVFoundation re-encodes the sounds, and the `.acd` is transcoded to
//  UTF-8 in memory.
//

import AppKit
import AVFoundation

enum AgentConverterError: LocalizedError {
    case noCharacterFile(URL)
    case noImages(URL)
    case unreadableImage(URL)
    case inconsistentSpriteSizes(URL)
    case noSounds(URL)
    case unusableSound(URL)
    case emptyName

    var errorDescription: String? {
        switch self {
        case .noCharacterFile(let url):
            return "No .acd character file found in \(url.lastPathComponent)."
        case .noImages(let url):
            return "No numbered .bmp sprites found in \(url.path)/Images."
        case .unreadableImage(let url):
            return "Could not read sprite \(url.lastPathComponent)."
        case .inconsistentSpriteSizes:
            return "Sprites differ in size; this is not a supported agent."
        case .noSounds(let url):
            return "No .wav sounds found in \(url.path)/Audio."
        case .unusableSound(let url):
            return "Could not read sound \(url.lastPathComponent)."
        case .emptyName:
            return "The agent name may not be empty."
        }
    }
}

enum AgentConverter {
    /// Widest sprite map we emit, matching the old script's `SPRITE_MAP_MAX_WIDTH`.
    /// SpriteKit's texture limit is 4096, so going wider would fail to load.
    static let spriteMapMaxWidth = 4096

    /// The order `Images/0000.bmp`, `Images/0001.bmp`, … is written in.
    static let spriteNumberPattern = try! NSRegularExpression(pattern: "^(\\d+)\\.bmp$", options: [.caseInsensitive])

    /// Builds `NAME.agent` inside the Agents directory and returns its URL.
    ///
    /// - Throws: any `AgentConverterError`, plus Foundation errors from reading
    ///   the source or writing the bundle.
    @discardableResult
    static func convert(agentAt sourceURL: URL, named name: String) throws -> URL {
        let sanitizedName = sanitize(name)
        guard !sanitizedName.isEmpty else { throw AgentConverterError.emptyName }

        let fileManager = FileManager.default
        let destinationURL = Agent.agentsURL().appendingPathComponent("\(sanitizedName).agent")
        let spriteMapURL = destinationURL.appendingPathComponent("\(sanitizedName)_sprite_map.png")
        let characterURL = destinationURL.appendingPathComponent("\(sanitizedName).acd")
        let soundsURL = destinationURL.appendingPathComponent("sounds")

        // A half-written bundle is worse than none: `Agent` would then find the
        // folder and fail to read it, so any error removes what we created.
        try? fileManager.removeItem(at: destinationURL)
        do {
            try fileManager.createDirectory(at: soundsURL, withIntermediateDirectories: true)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }

        do {
            try writeCharacterDefinition(from: sourceURL, to: characterURL, name: sanitizedName)
            try writeSpriteMap(from: sourceURL, to: spriteMapURL)
            try convertSounds(from: sourceURL, to: soundsURL, name: sanitizedName)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }

        AppLog.agent.info("Converted agent at \(sourceURL.path, privacy: .public) to \(destinationURL.path, privacy: .public)")
        return destinationURL
    }

    /// Keeps generated file names predictable: the `.acd` references
    /// `Images\N.bmp` and `Audio\N.wav` by bare index, and the sprite map is
    /// addressed by the same indices.
    static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return String(name.unicodeScalars.filter { allowed.contains($0) }).lowercased()
    }

    // MARK: - Character definition

    /// Decompilers emit `.acd` files as ISO-8859-1; the parser reads UTF-8, so
    /// the agent's localized names survive only if they are transcoded here.
    private static func writeCharacterDefinition(from sourceURL: URL, to destinationURL: URL, name: String) throws {
        let candidates = try FileManager.default.contentsOfDirectory(at: sourceURL,
                                                                    includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "acd" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard let source = candidates.first else { throw AgentConverterError.noCharacterFile(sourceURL) }

        // Latin-1 decodes any byte, so it is also the safe fallback for a file
        // that is already UTF-8 but carries a stray invalid byte.
        let text: String
        if let latin1 = try? String(contentsOf: source, encoding: .isoLatin1) {
            text = latin1
        } else {
            text = try String(contentsOf: source, encoding: .utf8)
        }
        try text.write(to: destinationURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Sprite map

    private static func writeSpriteMap(from sourceURL: URL, to destinationURL: URL) throws {
        let imagesURL = sourceURL.appendingPathComponent("Images")
        let sprites = try numberedSprites(in: imagesURL)
        guard !sprites.isEmpty else { throw AgentConverterError.noImages(sourceURL) }

        var keyed: [CGImage] = []
        keyed.reserveCapacity(sprites.count)
        for url in sprites {
            guard let image = colorKeyedImage(at: url) else { throw AgentConverterError.unreadableImage(url) }
            keyed.append(image)
        }

        guard let spriteSize = keyed.first.map({ CGSize(width: $0.width, height: $0.height) }) else {
            throw AgentConverterError.noImages(sourceURL)
        }
        // A ragged map would make every cell after the first odd-sized sprite
        // land in the wrong place, so it is rejected instead of silently skewed.
        guard keyed.allSatisfy({ $0.width == Int(spriteSize.width) && $0.height == Int(spriteSize.height) }) else {
            throw AgentConverterError.inconsistentSpriteSizes(sourceURL)
        }

        guard let map = spriteMap(from: keyed, spriteSize: spriteSize) else { throw AgentConverterError.noImages(sourceURL) }
        guard let data = NSBitmapImageRep(cgImage: map).representation(using: .png, properties: [:]) else {
            throw AgentConverterError.unreadableImage(destinationURL)
        }
        try data.write(to: destinationURL, options: .atomic)
    }

    /// Sprites ordered by their numeric filename, which is the index the `.acd`
    /// refers to. A plain sort would put `Images\10.bmp` before `Images\2.bmp`
    /// and scramble the whole map.
    private static func numberedSprites(in imagesURL: URL) throws -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: imagesURL,
                                                                         includingPropertiesForKeys: nil) else {
            return []
        }
        return contents
            .compactMap { url -> (Int, URL)? in
                let name = url.lastPathComponent
                let range = NSRange(name.startIndex..., in: name)
                guard let match = spriteNumberPattern.firstMatch(in: name, range: range),
                      let numberRange = Range(match.range(at: 1), in: name) else { return nil }
                return (Int(name[numberRange]) ?? -1, url)
            }
            .sorted { $0.0 == $1.0 ? $0.1.lastPathComponent < $1.1.lastPathComponent : $0.0 < $1.0 }
            .map(\.1)
    }

    /// Reads a sprite and makes every pixel of its background colour fully
    /// transparent.
    ///
    /// MS Agent bitmaps are opaque, with a flat background that is usually the
    /// same colour everywhere; the top-left pixel is its colour key. The old
    /// script drew `color 0,0 replace`, which cleared that one pixel and left
    /// the rest of the background visible.
    private static func colorKeyedImage(at url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url),
              let source = NSBitmapImageRep(data: data)?.cgImage else { return nil }
        let width = source.width
        let height = source.height
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        let keyRed = pixels[0], keyGreen = pixels[1], keyBlue = pixels[2]
        for index in stride(from: 0, to: pixels.count, by: 4)
        where pixels[index] == keyRed && pixels[index + 1] == keyGreen && pixels[index + 2] == keyBlue {
            pixels[index + 3] = 0
        }

        guard let output = CGContext(data: &pixels,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: width * 4,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        return output.makeImage()
    }

    /// Tiles the sprites left to right, top to bottom, exactly as
    /// `Agent.textureAtIndex(index:)` expects: index `n` sits at
    /// `x = n % columns`, `y = n / columns`, counted from the top left.
    private static func spriteMap(from sprites: [CGImage], spriteSize: CGSize) -> CGImage? {
        let spriteWidth = Int(spriteSize.width)
        let spriteHeight = Int(spriteSize.height)
        let columnsPerRow = max(1, spriteMapMaxWidth / max(spriteWidth, 1))
        let rows = Int(ceil(Double(sprites.count) / Double(columnsPerRow)))
        let mapWidth = columnsPerRow * spriteWidth
        let mapHeight = rows * spriteHeight

        guard let context = CGContext(data: nil,
                                      width: mapWidth,
                                      height: mapHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: mapWidth, height: mapHeight))

        for (index, sprite) in sprites.enumerated() {
            let column = index % columnsPerRow
            let row = index / columnsPerRow
            // Core Graphics counts rows from the bottom, the parser from the top.
            context.draw(sprite, in: CGRect(x: column * spriteWidth,
                                            y: mapHeight - (row + 1) * spriteHeight,
                                            width: spriteWidth,
                                            height: spriteHeight))
        }
        return context.makeImage()
    }

    // MARK: - Sounds

    /// Re-encodes `Audio\N.wav` to `NAME_N.m4a`, the layout `Agent.soundURL(forIndex:)`
    /// looks for. Sounds are indexed by their `.acd` reference, never by folder
    /// order, so the number is read from the file name.
    private static func convertSounds(from sourceURL: URL, to soundsURL: URL, name: String) throws {
        let audioURL = sourceURL.appendingPathComponent("Audio")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: audioURL,
                                                                         includingPropertiesForKeys: nil),
              !contents.isEmpty else {
            throw AgentConverterError.noSounds(sourceURL)
        }

        let soundNumberPattern = try! NSRegularExpression(pattern: "^(\\d+)\\.wav$", options: [.caseInsensitive])
        var converted = 0
        for url in contents {
            let fileName = url.lastPathComponent
            guard let match = soundNumberPattern.firstMatch(in: fileName,
                                                             range: NSRange(fileName.startIndex..., in: fileName)),
                  let numberRange = Range(match.range(at: 1), in: fileName) else { continue }

            let destination = soundsURL.appendingPathComponent("\(name)_\(fileName[numberRange]).m4a")
            do {
                try convertSound(at: url, to: destination)
                converted += 1
            } catch {
                AppLog.agent.error("Skipped sound \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        guard converted > 0 else { throw AgentConverterError.unusableSound(audioURL) }
    }

    /// Decodes to PCM and encodes back as AAC.
    ///
    /// MP3 is the one thing this cannot do: macOS ships an MP3 decoder but no
    /// encoder, so an MP3 export is not reachable from AVFoundation. AAC in an
    /// MPEG-4 container plays through the same `AVPlayer` and costs a fraction of
    /// the space, and `Agent` reads both this and the shipped `.mp3` files.
    private static func convertSound(at sourceURL: URL, to destinationURL: URL) throws {
        let input = try AVAudioFile(forReading: sourceURL)
        let inputFormat = input.processingFormat
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw AgentConverterError.unusableSound(sourceURL)
        }

        try? FileManager.default.removeItem(at: destinationURL)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
        ]
        let output = try AVAudioFile(forWriting: destinationURL,
                                     settings: outputSettings,
                                     commonFormat: .pcmFormatFloat32,
                                     interleaved: false)
        let outputFormat = output.processingFormat
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AgentConverterError.unusableSound(sourceURL)
        }

        // The converter pulls input through this block until it reports
        // `.endOfStream`, so a file whose length is not a multiple of the read
        // size is still written out in full.
        var readFailed = false
        while true {
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 8192)!
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
                guard !readFailed else {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4096)!
                do {
                    try input.read(into: inputBuffer, frameCount: 4096)
                } catch {
                    readFailed = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                if inputBuffer.frameLength == 0 {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return inputBuffer
            }

            if let conversionError { throw conversionError }
            if outputBuffer.frameLength > 0 { try output.write(from: outputBuffer) }
            if status == .endOfStream { break }
            if status == .error { throw AgentConverterError.unusableSound(sourceURL) }
        }
    }
}
