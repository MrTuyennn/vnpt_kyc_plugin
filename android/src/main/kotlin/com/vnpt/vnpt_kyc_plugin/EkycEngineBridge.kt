package com.vnpt.vnpt_kyc_plugin

import ai.icenter.face3d.native_lib.CardConfig
import ai.icenter.face3d.native_lib.CardWrapper
import ai.icenter.face3d.native_lib.Face3DConfig
import ai.icenter.face3d.native_lib.Face3DWrapper
import ai.icenter.face3d.native_lib.Utils
import android.content.Context
class EkycEngineBridge(
  private val context: Context,
  private var config: NativeEngineConfig = defaultConfig(),
) : EkycNativeEngine {

  private var ovalIsFarPhase: Boolean = true
  private var ovalPreviewWidth: Int = 480
  private var ovalPreviewHeight: Int = 640

  companion object {
    fun defaultConfig() = NativeEngineConfig(
      jpegQuality = 80,
      previewHeight = 180,
      ocrToken = "8928skjhfa89298jahga1771vbvb",
      isAutoCropParam = false,
    )
  }

  override fun configure(config: NativeEngineConfig) {
    this.config = config
  }

  private fun verifyModels() {
    for (model in listOf("cd.bic", "fdn.bic", "fdn0.bic", "ffd_screen.bic", "fl.bic", "rf.bic", "rp.bic")) {
      try {
        context.assets.openFd(model).close()
      } catch (error: java.io.IOException) {
        throw FlutterError("MODEL_UNAVAILABLE", "Không mở được model $model. Kiểm tra SDK assets và cấu hình noCompress cho bic.", null)
      }
    }
  }

  override fun cardCreateInstance() {
    verifyModels()
    CardWrapper.createInstance(context.applicationContext)
  }

  override fun cardDeleteInstance() {
    CardWrapper.deleteInstance()
  }

  override fun cardValidateV2(jpeg: ByteArray, isFront: Boolean): Long {
    val bmp = EkycBitmapUtil.decodeJpeg(jpeg)
    val scaled = EkycBitmapUtil.scaleToPreviewHeight(bmp, config.previewHeight.toInt())
    val side = if (isFront) 0 else 1
    val cardConfig = CardConfig(true, side)
    val msg = CardWrapper.validateV2(scaled, cardConfig)
    val value = when (msg) {
      Utils.MESSAGE.CARD_VALID -> 20L
      Utils.MESSAGE.NO_CARD -> 21L
      Utils.MESSAGE.CARD_BRIGHT -> 22L
      Utils.MESSAGE.CARD_LEFT -> 23L
      Utils.MESSAGE.CARD_TOP -> 24L
      Utils.MESSAGE.CARD_RIGHT -> 25L
      Utils.MESSAGE.CARD_BOTTOM -> 26L
      Utils.MESSAGE.CARD_BLUR -> 27L
      Utils.MESSAGE.CARD_NEAR -> 28L
      Utils.MESSAGE.CARD_FAR -> 29L
      Utils.MESSAGE.CARD_TILT -> 30L
      else -> -1L
    }
    return value
  }

  override fun cardPostCapture(jpeg: ByteArray, isFront: Boolean): CardPostCaptureResult {
    val bmp = EkycBitmapUtil.decodeJpeg(jpeg)
    val scaled = EkycBitmapUtil.scaleToPreviewHeight(bmp, config.previewHeight.toInt())
    val side = if (isFront) 0 else 1
    val cardConfig = CardConfig(true, side)
    val pixels = EkycBitmapUtil.pixelsFromBitmap(scaled)
    val result = CardWrapper.validate(pixels, cardConfig)
      ?: throw FlutterError("CARD", "Native validate(crop) returned null", null)

    val arr = result.array
    val cropBmp =
      if (arr != null && arr.size == scaled.width * scaled.height) {
        EkycBitmapUtil.bitmapFromPixels(arr, scaled.width, scaled.height)
      } else {
        scaled
      }
    val cropJpeg = EkycBitmapUtil.encodeJpeg(cropBmp, config.jpegQuality.toInt())
    val cropParam = if (config.isAutoCropParam) {
      "0.0,0.0"
    } else {
      EkycBitmapUtil.cropParamFromRect(0, scaled.height, scaled.height, false)
    }
    val token = result.tk?.takeIf { it.isNotBlank() } ?: config.ocrToken
    return CardPostCaptureResult(cropJpeg, cropParam, token)
  }

  override fun faceCreateInstance(timeLimitSec: Long) {
    verifyModels()
    val cfg = Face3DConfig(timeLimitSec.toInt().coerceAtLeast(10))
    Face3DWrapper.createInstance(context.applicationContext, cfg)
  }

  override fun faceDeleteInstance() {
    Face3DWrapper.deleteInstance()
  }

  override fun faceSetOvalPhase(isFar: Boolean) {
    ovalIsFarPhase = isFar
  }

  override fun faceSetPreviewSize(width: Long, height: Long) {
    ovalPreviewWidth = width.toInt().coerceAtLeast(1)
    ovalPreviewHeight = height.toInt().coerceAtLeast(1)
  }

  override fun faceOvalCropJpeg(jpeg: ByteArray): ByteArray {
    val cropped = EkycOvalFramePrep.engineBitmap(
      jpeg,
      ovalPreviewWidth,
      ovalPreviewHeight,
      config.previewHeight.toInt(),
      ovalIsFarPhase,
    )
    return EkycBitmapUtil.encodeJpeg(cropped, config.jpegQuality.toInt())
  }

  override fun faceProcessFrame(jpeg: ByteArray): Long {
    val cropped = EkycOvalFramePrep.engineBitmap(
      jpeg,
      ovalPreviewWidth,
      ovalPreviewHeight,
      config.previewHeight.toInt(),
      ovalIsFarPhase,
    )
    val msg = Face3DWrapper.process(cropped)
    // Android enum ordinals differ from the result values exposed by iOS/Dart.
    val result = when (msg) {
      Utils.MESSAGE.NO_FACE -> 0L
      Utils.MESSAGE.FIT -> 1L
      Utils.MESSAGE.TOO_FAR -> 2L
      Utils.MESSAGE.TOO_NEAR -> 3L
      Utils.MESSAGE.TIME_EXCEED -> 4L
      Utils.MESSAGE.NOT_STRAIGHT -> 5L
      Utils.MESSAGE.AWAY_FROM_LEFT -> 6L
      Utils.MESSAGE.AWAY_FROM_TOP -> 7L
      Utils.MESSAGE.AWAY_FROM_RIGHT -> 8L
      Utils.MESSAGE.AWAY_FROM_BOTTOM -> 9L
      Utils.MESSAGE.AWAY_FROM_CENTER -> 10L
      Utils.MESSAGE.MANY_FACES -> 19L
      else -> -1L
    }
    return result
  }

  override fun faceNotifyCapture() {
    Face3DWrapper.notifyCapture()
  }

  override fun faceGet3DScan(): String = Face3DWrapper.get3DScan()

  override fun faceCaptureV1(logLines: String): String {
    val sb = StringBuilder(logLines)
    return Face3DWrapper.captureV1(sb)
  }
}
