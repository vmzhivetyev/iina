//
//  ReencodeSettingsWindowController.swift
//  iina
//
//  Created for video re-encoding settings window with programmatic UI
//

import Cocoa

class ReencodeSettingsWindowController: NSWindowController {

  // MARK: - UI Elements

  private var qualityTextField: NSTextField!
  private var qualitySlider: NSSlider!
  private var speedSlider: NSSlider!
  private var speedTextField: NSTextField!
  private var volumeTextField: NSTextField!
  private var silentCheckbox: NSButton!
  private var startTimeLabel: NSTextField!
  private var endTimeLabel: NSTextField!
  private var durationLabel: NSTextField!
  private var outputPathTextField: NSTextField!
  private var codecPopup: NSPopUpButton!
  private var encodeButton: NSButton!
  private var cancelButton: NSButton!

  // MARK: - Properties

  var reencodeManager: VideoReencodeManager
  var onEncode: ((VideoReencodeManager.ReencodeSettings) -> Void)?
  var onCancel: (() -> Void)?

  private var settings = VideoReencodeManager.ReencodeSettings()

  // MARK: - Initialization

  init(reencodeManager: VideoReencodeManager) {
    self.reencodeManager = reencodeManager

    // Create the panel
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    panel.title = "Re-encode Video Settings"
    panel.isReleasedWhenClosed = false
    panel.center()

    super.init(window: panel)

    setupUI()
    loadInitialValues()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - UI Setup

  private func setupUI() {
    guard let panel = window as? NSPanel else { return }

    // Main stack view
    let mainStack = NSStackView()
    mainStack.orientation = .vertical
    mainStack.spacing = 16
    mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    mainStack.translatesAutoresizingMaskIntoConstraints = false

    // Time range section
    let timeRangeStack = createTimeRangeSection()
    mainStack.addArrangedSubview(timeRangeStack)

    // Quality section
    let qualityStack = createQualitySection()
    mainStack.addArrangedSubview(qualityStack)

    // Speed section
    let speedStack = createSpeedSection()
    mainStack.addArrangedSubview(speedStack)

    // Volume section
    let volumeStack = createVolumeSection()
    mainStack.addArrangedSubview(volumeStack)

    // Codec section
    let codecStack = createCodecSection()
    mainStack.addArrangedSubview(codecStack)

    // Output path section
    let outputStack = createOutputSection()
    mainStack.addArrangedSubview(outputStack)

    // Spacer
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    mainStack.addArrangedSubview(spacer)

    // Buttons section
    let buttonStack = createButtonSection()
    mainStack.addArrangedSubview(buttonStack)

    // Add main stack to content view
    let contentView = NSView()
    contentView.addSubview(mainStack)

    NSLayoutConstraint.activate([
      mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
      mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    ])

    panel.contentView = contentView
  }

  private func createTimeRangeSection() -> NSView {
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.spacing = 8

    let titleLabel = NSTextField(labelWithString: "Time Range:")
    titleLabel.font = .boldSystemFont(ofSize: 13)

    startTimeLabel = NSTextField(labelWithString: "Start: --:--")
    endTimeLabel = NSTextField(labelWithString: "End: --:--")
    durationLabel = NSTextField(labelWithString: "Duration: --:--")

    stack.addArrangedSubview(titleLabel)
    stack.addArrangedSubview(startTimeLabel)
    stack.addArrangedSubview(endTimeLabel)
    stack.addArrangedSubview(durationLabel)

    return stack
  }

  private func createQualitySection() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.spacing = 8

    let label = NSTextField(labelWithString: "Quality (0-100):")
    label.alignment = .right
    label.widthAnchor.constraint(equalToConstant: 120).isActive = true

    qualitySlider = NSSlider(value: 60, minValue: 0, maxValue: 100, target: self, action: #selector(qualitySliderChanged))
    qualitySlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

    qualityTextField = NSTextField(string: "60")
    qualityTextField.widthAnchor.constraint(equalToConstant: 50).isActive = true
    qualityTextField.delegate = self

    stack.addArrangedSubview(label)
    stack.addArrangedSubview(qualitySlider)
    stack.addArrangedSubview(qualityTextField)

    return stack
  }

  private func createSpeedSection() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.spacing = 8

    let label = NSTextField(labelWithString: "Speed:")
    label.alignment = .right
    label.widthAnchor.constraint(equalToConstant: 120).isActive = true

    // Speed slider: 0.25x to 4x (logarithmic would be better, but linear is simpler)
    speedSlider = NSSlider(value: 1.0, minValue: 0.25, maxValue: 4.0, target: self, action: #selector(speedSliderChanged))
    speedSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

    speedTextField = NSTextField(string: "1.0")
    speedTextField.placeholderString = "1.0"
    speedTextField.widthAnchor.constraint(equalToConstant: 50).isActive = true
    speedTextField.delegate = self

    let infoLabel = NSTextField(labelWithString: "x")
    infoLabel.alignment = .left

    let descLabel = NSTextField(labelWithString: "(0.25x = 4× slower, 4x = 4× faster)")
    descLabel.font = .systemFont(ofSize: 10)
    descLabel.textColor = .secondaryLabelColor

    let textStack = NSStackView()
    textStack.orientation = .horizontal
    textStack.spacing = 2
    textStack.addArrangedSubview(speedTextField)
    textStack.addArrangedSubview(infoLabel)

    let controlStack = NSStackView()
    controlStack.orientation = .vertical
    controlStack.spacing = 4
    controlStack.addArrangedSubview(textStack)
    controlStack.addArrangedSubview(descLabel)

    stack.addArrangedSubview(label)
    stack.addArrangedSubview(speedSlider)
    stack.addArrangedSubview(controlStack)

    return stack
  }

  private func createVolumeSection() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.spacing = 8

    let label = NSTextField(labelWithString: "Volume:")
    label.alignment = .right
    label.widthAnchor.constraint(equalToConstant: 120).isActive = true

    volumeTextField = NSTextField(string: "")
    volumeTextField.placeholderString = "Optional (e.g., 0.1, 0.5, 1.0, 2.0)"
    volumeTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true

    silentCheckbox = NSButton(checkboxWithTitle: "Silent audio", target: self, action: #selector(silentCheckboxChanged))

    let infoStack = NSStackView()
    infoStack.orientation = .vertical
    infoStack.spacing = 4
    infoStack.addArrangedSubview(volumeTextField)
    infoStack.addArrangedSubview(silentCheckbox)

    stack.addArrangedSubview(label)
    stack.addArrangedSubview(infoStack)

    return stack
  }

  private func createCodecSection() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.spacing = 8

    let label = NSTextField(labelWithString: "Codec:")
    label.alignment = .right
    label.widthAnchor.constraint(equalToConstant: 120).isActive = true

    codecPopup = NSPopUpButton()
    codecPopup.addItems(withTitles: [
      "hevc_videotoolbox",
      "h264_videotoolbox",
      "libx265",
      "libx264"
    ])
    codecPopup.selectItem(at: 0)
    codecPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true

    stack.addArrangedSubview(label)
    stack.addArrangedSubview(codecPopup)

    return stack
  }

  private func createOutputSection() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.spacing = 8

    let label = NSTextField(labelWithString: "Output:")
    label.alignment = .right
    label.widthAnchor.constraint(equalToConstant: 120).isActive = true

    outputPathTextField = NSTextField(string: "")
    outputPathTextField.placeholderString = "Auto-generated"
    outputPathTextField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

    let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseOutputPath))
    browseButton.bezelStyle = .rounded

    stack.addArrangedSubview(label)
    stack.addArrangedSubview(outputPathTextField)
    stack.addArrangedSubview(browseButton)

    return stack
  }

  private func createButtonSection() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.spacing = 12

    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

    cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelAction))
    cancelButton.bezelStyle = .rounded
    cancelButton.keyEquivalent = "\u{1b}" // Escape key

    encodeButton = NSButton(title: "Encode", target: self, action: #selector(encodeAction))
    encodeButton.bezelStyle = .rounded
    encodeButton.keyEquivalent = "\r" // Return key

    stack.addArrangedSubview(spacer)
    stack.addArrangedSubview(cancelButton)
    stack.addArrangedSubview(encodeButton)

    return stack
  }

  // MARK: - Data Loading

  private func loadInitialValues() {
    guard let start = reencodeManager.startTime,
          let end = reencodeManager.endTime else { return }

    let duration = end - start

    startTimeLabel.stringValue = "Start: \(reencodeManager.formatTimeForDisplay(start))"
    endTimeLabel.stringValue = "End: \(reencodeManager.formatTimeForDisplay(end))"
    durationLabel.stringValue = "Duration: \(reencodeManager.formatTimeForDisplay(duration))"

    // Load persisted settings
    let quality = Preference.integer(for: .reencodeQuality)
    qualitySlider.doubleValue = Double(quality)
    qualityTextField.stringValue = "\(quality)"
    settings.quality = quality

    let speed = Preference.double(for: .reencodeSpeed)
    if speed > 0 {
      speedSlider.doubleValue = speed
      speedTextField.stringValue = String(format: "%.2f", speed)
      settings.speedMultiplier = speed
    } else {
      // Default to 1.0 (normal speed)
      speedSlider.doubleValue = 1.0
      speedTextField.stringValue = "1.0"
    }

    let volume = Preference.double(for: .reencodeVolume)
    if volume > 0 {
      volumeTextField.stringValue = "\(volume)"
      settings.volume = volume
    }

    let silentAudio = Preference.bool(for: .reencodeSilentAudio)
    silentCheckbox.state = silentAudio ? .on : .off
    volumeTextField.isEnabled = !silentAudio
    settings.silentAudio = silentAudio

    let codec = Preference.string(for: .reencodeCodec) ?? "hevc_videotoolbox"
    if let index = codecPopup.itemTitles.firstIndex(of: codec) {
      codecPopup.selectItem(at: index)
    }
    settings.codec = codec
  }

  // MARK: - Actions

  @objc private func qualitySliderChanged(_ sender: NSSlider) {
    let value = Int(sender.doubleValue)
    qualityTextField.stringValue = "\(value)"
    settings.quality = value
    Preference.set(value, for: .reencodeQuality)
  }

  @objc private func speedSliderChanged(_ sender: NSSlider) {
    let value = sender.doubleValue
    speedTextField.stringValue = String(format: "%.2f", value)
    settings.speedMultiplier = value
    Preference.set(value, for: .reencodeSpeed)
  }

  @objc private func silentCheckboxChanged(_ sender: NSButton) {
    let isChecked = sender.state == .on
    volumeTextField.isEnabled = !isChecked
    settings.silentAudio = isChecked
    Preference.set(isChecked, for: .reencodeSilentAudio)
  }

  @objc private func browseOutputPath(_ sender: NSButton) {
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.mpeg4Movie]
    savePanel.nameFieldStringValue = "output.mp4"
    savePanel.canCreateDirectories = true

    savePanel.beginSheetModal(for: window!) { response in
      if response == .OK, let url = savePanel.url {
        self.outputPathTextField.stringValue = url.path
      }
    }
  }

  @objc private func encodeAction(_ sender: NSButton) {
    // Validate and collect settings
    settings.quality = Int(qualitySlider.doubleValue)

    // Parse speed multiplier
    if !speedTextField.stringValue.isEmpty {
      if let speed = Double(speedTextField.stringValue), speed > 0 {
        settings.speedMultiplier = speed
        Preference.set(speed, for: .reencodeSpeed)
      } else {
        showAlert("Invalid speed value. Please enter a positive number (e.g., 0.5 for slower, 2.0 for faster).")
        return
      }
    } else {
      settings.speedMultiplier = nil
      Preference.set(0.0, for: .reencodeSpeed)
    }

    // Parse volume
    if !volumeTextField.stringValue.isEmpty && !settings.silentAudio {
      if let volume = Double(volumeTextField.stringValue), volume > 0 {
        settings.volume = volume
        Preference.set(volume, for: .reencodeVolume)
      } else {
        showAlert("Invalid volume value. Please enter a positive number or leave it empty.")
        return
      }
    } else {
      settings.volume = nil
      Preference.set(0.0, for: .reencodeVolume)
    }

    // Get codec
    if let selectedCodec = codecPopup.selectedItem?.title {
      settings.codec = selectedCodec
      Preference.set(selectedCodec, for: .reencodeCodec)
    }

    // Get output path
    if !outputPathTextField.stringValue.isEmpty {
      settings.outputPath = outputPathTextField.stringValue
    }

    // Call the encode handler
    onEncode?(settings)

    // Close the window
    window?.sheetParent?.endSheet(window!, returnCode: .OK)
  }

  @objc private func cancelAction(_ sender: NSButton) {
    onCancel?()
    window?.sheetParent?.endSheet(window!, returnCode: .cancel)
  }

  private func showAlert(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Invalid Input"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: window!)
  }
}

// MARK: - NSTextFieldDelegate

extension ReencodeSettingsWindowController: NSTextFieldDelegate {
  func controlTextDidChange(_ obj: Notification) {
    if let textField = obj.object as? NSTextField {
      if textField == qualityTextField {
        if let value = Int(textField.stringValue), value >= 0, value <= 100 {
          qualitySlider.doubleValue = Double(value)
          settings.quality = value
          Preference.set(value, for: .reencodeQuality)
        }
      } else if textField == speedTextField {
        if let value = Double(textField.stringValue), value > 0, value <= 10.0 {
          speedSlider.doubleValue = min(value, 4.0) // Slider max is 4.0, but allow higher values in text field
          settings.speedMultiplier = value
          Preference.set(value, for: .reencodeSpeed)
        }
      }
    }
  }
}
