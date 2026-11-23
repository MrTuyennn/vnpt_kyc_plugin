package com.vnpt.vnpt_kyc_plugin

import android.graphics.Bitmap

/**
 * Parity `M.a(Bitmap)` → `R1.a` → `x.a` (height 180) → `Face3DWrapper.process`.
 */
object EkycOvalFramePrep {
  fun engineBitmap(
    jpeg: ByteArray,
    previewWidth: Int,
    previewHeight: Int,
    engineHeight: Int,
    isFar: Boolean,
  ): Bitmap {
    val upright = EkycBitmapUtil.decodeJpegUpright(jpeg)
    val preview = EkycOvalGeometry.PreviewSize(
      width = previewWidth.coerceAtLeast(1),
      height = previewHeight.coerceAtLeast(1),
    )
    val norm = if (isFar) EkycOvalGeometry.engineFar else EkycOvalGeometry.engineNear
    val previewRect = EkycOvalGeometry.rectInPreviewCoordinates(preview, norm)
    return EkycOvalGeometry.cropForEngine(
      bitmap = upright,
      preview = preview,
      previewRect = previewRect,
      engineHeight = engineHeight,
    )
  }
}
