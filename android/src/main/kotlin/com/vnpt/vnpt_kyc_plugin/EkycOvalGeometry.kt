package com.vnpt.vnpt_kyc_plugin

import android.graphics.Bitmap
import android.graphics.Rect
import kotlin.math.roundToInt

/**
 * Port `com.vnptit.idg.sdk.R1` — map preview-space oval rect → bitmap crop (letterbox / FIT_CENTER).
 */
object EkycOvalGeometry {
  data class PreviewSize(val width: Int, val height: Int)

  data class NormRect(val left: Float, val top: Float, val right: Float, val bottom: Float)

  /** Engine rects `M.q` / `M.r` (normalized on preview J4). */
  val engineFar =
    NormRect(0.2413f, 0.2101f, 0.7587f, 0.7899f)
  val engineNear =
    NormRect(0.0595f, 0.0935f, 0.9405f, 0.9065f)

  fun rectInPreviewCoordinates(preview: PreviewSize, norm: NormRect): Rect {
    val left = (preview.width * norm.left).roundToInt().coerceAtLeast(0)
    val top = (preview.height * norm.top).roundToInt().coerceAtLeast(0)
    val right = (preview.width * norm.right).roundToInt().coerceAtMost(preview.width)
    val bottom = (preview.height * norm.bottom).roundToInt().coerceAtMost(preview.height)
    return Rect(left, top, right.coerceAtLeast(left + 1), bottom.coerceAtLeast(top + 1))
  }

  /** `R1.a(J4 bitmapSize, J4 previewSize)` — active region in bitmap matching preview aspect. */
  fun letterboxInBitmap(bitmapW: Int, bitmapH: Int, preview: PreviewSize): Rect {
    if (bitmapW <= 0 || bitmapH <= 0 || preview.width <= 0 || preview.height <= 0) {
      return Rect(0, 0, bitmapW.coerceAtLeast(1), bitmapH.coerceAtLeast(1))
    }
    val dstAspect = preview.width.toFloat() / preview.height
    val srcAspect = bitmapW.toFloat() / bitmapH
    return if (srcAspect > dstAspect) {
      val scaledW = (bitmapH * dstAspect).roundToInt().coerceAtMost(bitmapW)
      val left = (bitmapW - scaledW) / 2
      Rect(left, 0, left + scaledW, bitmapH)
    } else {
      val scaledH = (bitmapW / dstAspect).roundToInt().coerceAtMost(bitmapH)
      val top = (bitmapH - scaledH) / 2
      Rect(0, top, bitmapW, top + scaledH)
    }
  }

  /** `R1.a(bitmap, J4 preview, Rect previewPx)` then engine scale height. */
  fun cropForEngine(
    bitmap: Bitmap,
    preview: PreviewSize,
    previewRect: Rect,
    engineHeight: Int,
  ): Bitmap {
    if (bitmap.width == preview.width && bitmap.height == preview.height) {
      val safe = Rect(
        previewRect.left.coerceIn(0, bitmap.width - 1),
        previewRect.top.coerceIn(0, bitmap.height - 1),
        previewRect.right.coerceIn(previewRect.left + 1, bitmap.width),
        previewRect.bottom.coerceIn(previewRect.top + 1, bitmap.height),
      )
      val cropped = Bitmap.createBitmap(bitmap, safe.left, safe.top, safe.width(), safe.height())
      return EkycBitmapUtil.scaleToPreviewHeight(cropped, engineHeight)
    }
    val letterbox = letterboxInBitmap(bitmap.width, bitmap.height, preview)
    val scale = letterbox.width().toFloat() / preview.width
    val crop = Rect(
      (letterbox.left + previewRect.left * scale).roundToInt(),
      (letterbox.top + previewRect.top * scale).roundToInt(),
      (letterbox.left + previewRect.right * scale).roundToInt(),
      (letterbox.top + previewRect.bottom * scale).roundToInt(),
    )
    val safe = Rect(
      crop.left.coerceIn(0, bitmap.width - 1),
      crop.top.coerceIn(0, bitmap.height - 1),
      crop.right.coerceIn(crop.left + 1, bitmap.width),
      crop.bottom.coerceIn(crop.top + 1, bitmap.height),
    )
    val cropped = Bitmap.createBitmap(
      bitmap,
      safe.left,
      safe.top,
      safe.width(),
      safe.height(),
    )
    return EkycBitmapUtil.scaleToPreviewHeight(cropped, engineHeight)
  }
}