//
//  VideoReencodeManager.swift
//  iina
//
//  Created for video re-encoding and trimming feature
//

import Cocoa

class VideoReencodeManager {

  // MARK: - Properties

  var startTime: Double?
  var endTime: Double?
  var inputVideoPath: String?

  private var ffmpegProcess: Process?
  private var progressHandler: ((String) -> Void)?
  private var completionHandler: ((Bool, String?) -> Void)?

  // MARK: - Configuration

  struct ReencodeSettings {
    var quality: Int = 60
    var fps: Double?
    var volume: Double?
    var silentAudio: Bool = false
    var codec: String = "hevc_videotoolbox"
    var outputPath: String?
  }

  // MARK: - Public Methods

  func setStartPoint(time: Double, videoPath: String) {
    self.startTime = time
    self.inputVideoPath = videoPath
    Logger.log("Re-encode start point set to: \(formatTime(time))", level: .verbose)
  }

  func setEndPoint(time: Double) {
    self.endTime = time
    Logger.log("Re-encode end point set to: \(formatTime(time))", level: .verbose)
  }

  func reset() {
    startTime = nil
    endTime = nil
    inputVideoPath = nil
  }

  func hasValidRange() -> Bool {
    guard let start = startTime, let end = endTime else { return false }
    return end > start
  }

  // MARK: - FFmpeg Command Building

  func buildFFmpegCommand(settings: ReencodeSettings) -> (command: String, arguments: [String], outputPath: String)? {
    guard let inputPath = inputVideoPath,
          let start = startTime,
          let end = endTime else {
      Logger.log("Missing required parameters for re-encoding", level: .error)
      return nil
    }

    // Generate output path
    let outputPath = settings.outputPath ?? generateOutputPath(
      inputPath: inputPath,
      start: start,
      end: end,
      settings: settings
    )

    var args: [String] = []

    // Input trimming parameters (before -i for efficient seeking)
    args.append("-ss")
    args.append(formatTime(start))
    args.append("-to")
    args.append(formatTime(end))

    // Input file
    args.append("-i")
    args.append(inputPath)

    // Build filter chains
    var videoFilters: [String] = []
    var audioFilters: [String] = []

    // Video filters (fps adjustment for slow motion)
    if let fps = settings.fps {
      videoFilters.append("setpts=PTS*(30/\(fps))")
    }

    // Audio filters (volume adjustment)
    if let volume = settings.volume, !settings.silentAudio {
      // Convert perceptual volume to dB
      // Formula: dB = 20 * log10(volume)
      let volumeDB = 20 * log10(volume)
      audioFilters.append("volume=\(String(format: "%.2f", volumeDB))dB")
    }

    // Handle silent audio
    if settings.silentAudio {
      args.append("-f")
      args.append("lavfi")
      args.append("-i")
      args.append("anullsrc=channel_layout=stereo:sample_rate=44100")
      args.append("-map")
      args.append("0:v:0")
      args.append("-map")
      args.append("1:a:0")

      // Add video filters if any
      if !videoFilters.isEmpty {
        args.append("-vf")
        args.append(videoFilters.joined(separator: ","))
      }

      args.append("-c:v")
      args.append(settings.codec)
      args.append("-q:v")
      args.append("\(settings.quality)")
      args.append("-tag:v")
      args.append("hvc1")
      args.append("-c:a")
      args.append("aac")
      args.append("-shortest")
    } else {
      // Add video filters if any
      if !videoFilters.isEmpty {
        args.append("-vf")
        args.append(videoFilters.joined(separator: ","))
      }

      // Add audio filters if any
      if !audioFilters.isEmpty {
        args.append("-af")
        args.append(audioFilters.joined(separator: ","))
      }

      args.append("-c:v")
      args.append(settings.codec)
      args.append("-q:v")
      args.append("\(settings.quality)")
      args.append("-tag:v")
      args.append("hvc1")

      // Use aac codec if we're processing audio, otherwise copy
      if !audioFilters.isEmpty {
        args.append("-c:a")
        args.append("aac")
      } else {
        args.append("-c:a")
        args.append("copy")
      }
    }

    // Output file
    args.append(outputPath)
    args.append("-y")  // Overwrite output file

    return (command: findFFmpegPath(), arguments: args, outputPath: outputPath)
  }

  // MARK: - Execution

  func executeReencode(
    settings: ReencodeSettings,
    onProgress: @escaping (String) -> Void,
    onCompletion: @escaping (Bool, String?) -> Void
  ) {
    guard let commandData = buildFFmpegCommand(settings: settings) else {
      onCompletion(false, "Failed to build ffmpeg command")
      return
    }

    self.progressHandler = onProgress
    self.completionHandler = onCompletion

    let process = Process()
    process.executableURL = URL(fileURLWithPath: commandData.command)
    process.arguments = commandData.arguments

    // Setup output pipes
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    // Read stderr for progress updates
    errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      if let output = String(data: data, encoding: .utf8), !output.isEmpty {
        DispatchQueue.main.async {
          self?.progressHandler?(output)
        }
      }
    }

    // Completion handler
    process.terminationHandler = { [weak self] process in
      DispatchQueue.main.async {
        let success = process.terminationStatus == 0
        let message = success ? commandData.outputPath : "FFmpeg process failed with status \(process.terminationStatus)"
        self?.completionHandler?(success, message)
        self?.ffmpegProcess = nil
      }
    }

    // Start the process
    do {
      try process.run()
      self.ffmpegProcess = process
      Logger.log("Started ffmpeg re-encoding to: \(commandData.outputPath)", level: .verbose)
    } catch {
      Logger.log("Failed to start ffmpeg: \(error.localizedDescription)", level: .error)
      onCompletion(false, "Failed to start ffmpeg: \(error.localizedDescription)")
    }
  }

  func cancelReencode() {
    ffmpegProcess?.terminate()
    ffmpegProcess = nil
    Logger.log("Re-encoding cancelled", level: .verbose)
  }

  func isEncoding() -> Bool {
    return ffmpegProcess?.isRunning ?? false
  }

  // MARK: - Helper Methods

  private func findFFmpegPath() -> String {
    // Common locations for ffmpeg
    let possiblePaths = [
      "/opt/homebrew/bin/ffmpeg",  // Homebrew on Apple Silicon
      "/usr/local/bin/ffmpeg",      // Homebrew on Intel
      "/usr/bin/ffmpeg",            // System location
      "/opt/local/bin/ffmpeg"       // MacPorts
    ]

    for path in possiblePaths {
      if FileManager.default.fileExists(atPath: path) {
        return path
      }
    }

    // Try to find ffmpeg in PATH
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["ffmpeg"]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
      try process.run()
      process.waitUntilExit()

      if process.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
          return path
        }
      }
    } catch {
      Logger.log("Failed to search for ffmpeg: \(error)", level: .error)
    }

    // Fallback to default
    return "/usr/bin/ffmpeg"
  }

  private func formatTime(_ seconds: Double) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
    return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, milliseconds)
  }

  func formatTimeForDisplay(_ seconds: Double) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = seconds.truncatingRemainder(dividingBy: 60)

    if hours > 0 {
      return String(format: "%d:%02d:%05.2f", hours, minutes, secs)
    } else {
      return String(format: "%d:%05.2f", minutes, secs)
    }
  }

  private func generateOutputPath(
    inputPath: String,
    start: Double,
    end: Double,
    settings: ReencodeSettings
  ) -> String {
    let url = URL(fileURLWithPath: inputPath)
    let directory = url.deletingLastPathComponent()
    let filename = url.deletingPathExtension().lastPathComponent

    // Build suffix based on settings
    var suffix = "_reencode"

    // Add time range
    let startStr = formatTimeForFilename(start)
    let endStr = formatTimeForFilename(end)
    suffix += "_\(startStr)-\(endStr)"

    // Add quality
    suffix += "_q\(settings.quality)"

    // Add fps if specified
    if let fps = settings.fps {
      let fpsStr = String(format: "%.0f", fps)
      suffix += "_\(fpsStr)fps"
    }

    // Add volume if specified
    if let volume = settings.volume, !settings.silentAudio {
      let volumeStr = String(format: "%.1f", volume).replacingOccurrences(of: ".", with: "_")
      suffix += "_vol\(volumeStr)"
    }

    // Add silent marker if applicable
    if settings.silentAudio {
      suffix += "_silent"
    }

    let outputFilename = "\(filename)\(suffix).mp4"
    return directory.appendingPathComponent(outputFilename).path
  }

  private func formatTimeForFilename(_ seconds: Double) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60

    if hours > 0 {
      return String(format: "%d-%02d-%02d", hours, minutes, secs)
    } else {
      return String(format: "%d-%02d", minutes, secs)
    }
  }
}
