import Flutter
import UIKit
import eKYCLib

final class EkycEngineBridge: EkycNativeEngine {
  private var config: NativeEngineConfig
  private var ovalIsFarPhase = true
  private var ovalPreviewWidth = 480
  private var ovalPreviewHeight = 640

  init(config: NativeEngineConfig) {
    self.config = config
  }

  func configure(config: NativeEngineConfig) throws {
    self.config = config
  }

  func cardCreateInstance() throws {
    CardWrapper.createInstance()
  }

  func cardDeleteInstance() throws {
    CardWrapper.deleteInstance()
  }

  func cardValidateV2(jpeg: FlutterStandardTypedData, isFront: Bool) throws -> Int64 {
    let img = try EkycIosBitmap.jpegFromData(jpeg.data)
    let upright = EkycIosBitmap.upright(img)
    let side: Int = isFront ? 0 : 1
    let cardConfig = CardConfig(isCheckAutoCard: true, type: side)
    let msg = CardWrapper.validateV2(bmp: upright, cardConfig: cardConfig)
    return Self.cardResult(msg)
  }

  func cardPostCapture(jpeg: FlutterStandardTypedData, isFront: Bool) throws -> CardPostCaptureResult {
    let img = try EkycIosBitmap.jpegFromData(jpeg.data)
    let upright = EkycIosBitmap.upright(img)
    guard let cropData = EkycIosBitmap.jpegData(upright, quality: CGFloat(config.jpegQuality) / 100.0) else {
      throw NSError(domain: "CARD", code: 0, userInfo: [NSLocalizedDescriptionKey: "JPEG encode failed"])
    }
    let cropParam = "0.0,0.0"
    let token = config.ocrToken
    return CardPostCaptureResult(cropJpeg: FlutterStandardTypedData(bytes: cropData), cropParam: cropParam, ocrToken: token)
  }

  func faceCreateInstance(timeLimitSec: Int64) throws {
    let cfg = Face3DConfig(time: Int(timeLimitSec))
    Face3DWrapper.createInstance(cfg: cfg)
  }

  func faceDeleteInstance() throws {
    Face3DWrapper.deleteInstance()
  }

  func faceSetOvalPhase(isFar: Bool) throws {
    ovalIsFarPhase = isFar
  }

  func faceSetPreviewSize(width: Int64, height: Int64) throws {
    ovalPreviewWidth = max(1, Int(width))
    ovalPreviewHeight = max(1, Int(height))
  }

  private func engineOvalImage(from jpeg: Data) throws -> UIImage {
    let img = try EkycIosBitmap.jpegFromData(jpeg)
    let upright = EkycIosBitmap.upright(img)
    let preview = EkycOvalGeometry.PreviewSize(width: ovalPreviewWidth, height: ovalPreviewHeight)
    return try EkycOvalGeometry.cropForEngine(image: upright, preview: preview, isFar: ovalIsFarPhase)
  }

  func faceOvalCropJpeg(jpeg: FlutterStandardTypedData) throws -> FlutterStandardTypedData {
    let img = try engineOvalImage(from: jpeg.data)
    guard let data = EkycIosBitmap.jpegData(img, quality: CGFloat(config.jpegQuality) / 100.0) else {
      throw NSError(domain: "FACE", code: 0, userInfo: [NSLocalizedDescriptionKey: "JPEG encode failed"])
    }
    return FlutterStandardTypedData(bytes: data)
  }

  func faceProcessFrame(jpeg: FlutterStandardTypedData) throws -> Int64 {
    let scaled = try engineOvalImage(from: jpeg.data)
    let msg = Face3DWrapper.process(bmp: scaled)
    return Self.faceResult(msg)
  }

  func faceNotifyCapture() throws {
    Face3DWrapper.notifyCapture()
  }

  func faceGet3DScan() throws -> String {
    Face3DWrapper.get3DScan()
  }

  func faceCaptureV1(logLines: String) throws -> String {
    Face3DWrapper.captureV1(log1: logLines)
  }

  // MARK: - MESSAGE_RESULT -> mã Dart (`MessageResult`)
  //
  // Nguồn đối chiếu: `eKYCLib.xcframework/ios-arm64/eKYCLib.framework/Modules/
  // eKYCLib.swiftmodule/arm64-apple-ios.swiftinterface` (enum `MESSAGE_RESULT : Int`,
  // SDK iOS v3.7.1) và bảng map Android trong `EkycEngineBridge.kt`
  // (`Utils.MESSAGE.*` -> mã Dart). Mã nào Dart không dùng -> -1 (như Android `else`).
  // Không dùng `rawValue` trực tiếp: enum iOS có thêm các giá trị 11–18, 31–35
  // (UNBALANCED, STRAIGHT, LEFT_20_30, ..., LIVENESS_*, CARD_FLIPPING_*) mà Android
  // không có tương ứng.

  static func faceResult(_ msg: MESSAGE_RESULT) -> Int64 {
    switch msg {
    case .NO_FACE: return 0
    case .FIT: return 1
    case .TOO_FAR: return 2
    case .TOO_NEAR: return 3
    case .TIME_EXCEED: return 4
    case .NOT_STRAIGHT: return 5
    case .AWAY_FROM_LEFT: return 6
    case .AWAY_FROM_TOP: return 7
    case .AWAY_FROM_RIGHT: return 8
    case .AWAY_FROM_BOTTOM: return 9
    case .AWAY_FROM_CENTER: return 10
    case .MANY_FACES: return 19
    default: return -1
    }
  }

  static func cardResult(_ msg: MESSAGE_RESULT) -> Int64 {
    switch msg {
    case .CARD_VALID: return 20
    case .NO_CARD: return 21
    case .CARD_BRIGHT: return 22
    case .CARD_LEFT: return 23
    case .CARD_TOP: return 24
    case .CARD_RIGHT: return 25
    case .CARD_BOTTOM: return 26
    case .CARD_BLUR: return 27
    case .CARD_NEAR: return 28
    case .CARD_FAR: return 29
    case .CARD_TILT: return 30
    default: return -1
    }
  }
}
