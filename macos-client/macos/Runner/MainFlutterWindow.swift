import Cocoa
import FlutterMacOS
import AVFoundation

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    registerMediaTestChannel(flutterViewController)
    registerWindowChannel(flutterViewController)

    super.awakeFromNib()
  }

  //--------------------------------------------------------------------------
  // 창 제어 채널 (영상 전체 화면)
  //--------------------------------------------------------------------------
  private func registerWindowChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "kibal/window", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      let isFull = self.styleMask.contains(.fullScreen)
      switch call.method {
      case "isFullScreen":
        result(isFull)
      case "setFullScreen":
        let want = (call.arguments as? Bool) ?? !isFull
        if want != isFull { self.toggleFullScreen(nil) }
        result(want)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  //--------------------------------------------------------------------------
  // 미디어 테스트 채널 (카메라/마이크 목록, 마이크 레벨 미터)
  //--------------------------------------------------------------------------
  private func registerMediaTestChannel(_ controller: FlutterViewController) {
    let service = MicMeterService.shared
    let channel = FlutterMethodChannel(
      name: "kibal/media_test", binaryMessenger: controller.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "listCameras":
        let session = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInWideAngleCamera],
          mediaType: .video,
          position: .unspecified)
        result(session.devices.map { d in
          ["id": d.uniqueID, "name": d.localizedName]
        })
      case "listMics":
        let session = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInMicrophone],
          mediaType: .audio,
          position: .unspecified)
        result(session.devices.map { d in
          ["id": d.uniqueID, "name": d.localizedName]
        })
      case "startMicMeter":
        do {
          try service.start()
          result(true)
        } catch {
          result(FlutterError(code: "meter_start", message: "\(error)", details: nil))
        }
      case "stopMicMeter":
        service.stop()
        result(true)
      case "readMicLevels":
        service.updateMeters()
        result(["avg": service.averageDb, "peak": service.peakDb])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// macOS 마이크 입력 레벨 미터 (AVAudioRecorder metering 기반)
final class MicMeterService: NSObject {
  static let shared = MicMeterService()
  private var recorder: AVAudioRecorder?
  private var _averageDb: Double = -160
  private var _peakDb: Double = -160

  func start() throws {
    stop()
    let dir = FileManager.default.temporaryDirectory
    let url = dir.appendingPathComponent("kibal_meter_\(Int(Date().timeIntervalSince1970)).caf")
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
    ]
    let rec = try AVAudioRecorder(url: url, settings: settings)
    rec.isMeteringEnabled = true
    rec.delegate = self
    guard rec.record() else {
      throw NSError(domain: "kibal.meter", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "AVAudioRecorder.record() 실패"])
    }
    recorder = rec
  }

  func stop() {
    recorder?.stop()
    recorder = nil
    _averageDb = -160
    _peakDb = -160
  }

  func updateMeters() {
    guard let rec = recorder, rec.isMeteringEnabled else { return }
    rec.updateMeters()
    _averageDb = Double(rec.averagePower(forChannel: 0))
    _peakDb = Double(rec.peakPower(forChannel: 0))
  }

  var averageDb: Double { _averageDb }
  var peakDb: Double { _peakDb }
}

extension MicMeterService: AVAudioRecorderDelegate {
  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    print("[MicMeter] finished flag=\(flag)")
  }
}
