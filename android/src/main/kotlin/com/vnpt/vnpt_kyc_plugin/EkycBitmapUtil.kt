package com.vnpt.vnpt_kyc_plugin

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.math.ceil

object EkycBitmapUtil {
  fun decodeJpeg(jpeg: ByteArray): Bitmap {
    val opts = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
    return BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size, opts)
      ?: throw FlutterError("DECODE", "Invalid JPEG", null)
  }

  fun decodeJpegUpright(jpeg: ByteArray): Bitmap {
    val bmp = decodeJpeg(jpeg)
    val exif = ExifInterface(ByteArrayInputStream(jpeg))
    val orientation = exif.getAttributeInt(
      ExifInterface.TAG_ORIENTATION,
      ExifInterface.ORIENTATION_NORMAL,
    )
    val degrees = when (orientation) {
      ExifInterface.ORIENTATION_ROTATE_90 -> 90
      ExifInterface.ORIENTATION_ROTATE_180 -> 180
      ExifInterface.ORIENTATION_ROTATE_270 -> 270
      else -> 0
    }
    if (degrees == 0) return bmp
    val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
    return Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
  }

  fun cropNormalizedRect(
    bitmap: Bitmap,
    left: Float,
    top: Float,
    right: Float,
    bottom: Float,
  ): Bitmap {
    val x0 = (left * bitmap.width).toInt().coerceIn(0, bitmap.width - 1)
    val y0 = (top * bitmap.height).toInt().coerceIn(0, bitmap.height - 1)
    val x1 = (right * bitmap.width).toInt().coerceIn(x0 + 1, bitmap.width)
    val y1 = (bottom * bitmap.height).toInt().coerceIn(y0 + 1, bitmap.height)
    val w = x1 - x0
    val h = y1 - y0
    return Bitmap.createBitmap(bitmap, x0, y0, w, h)
  }

  fun flipHorizontal(bitmap: Bitmap): Bitmap {
    val matrix = Matrix().apply { preScale(-1f, 1f) }
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
  }

  fun scaleToPreviewHeight(bitmap: Bitmap, previewHeight: Int): Bitmap {
    if (bitmap.height <= previewHeight) return bitmap
    val scale = previewHeight.toFloat() / bitmap.height
    val matrix = Matrix().apply { setScale(scale, scale) }
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
  }

  fun encodeJpeg(bitmap: Bitmap, quality: Int): ByteArray {
    val out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(1, 100), out)
    return out.toByteArray()
  }

  fun pixelsFromBitmap(bitmap: Bitmap): IntArray {
    val pixels = IntArray(bitmap.width * bitmap.height)
    bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
    return pixels
  }

  fun bitmapFromPixels(pixels: IntArray, width: Int, height: Int): Bitmap {
    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    bmp.setPixels(pixels, 0, width, 0, 0, width, height)
    return bmp
  }

  fun cropParamFromRect(top: Int, bottom: Int, imageHeight: Int, auto: Boolean): String {
    if (auto || imageHeight <= 0) return "0.0,0.0"
    val topPct = ceil(top.toFloat() / imageHeight * 100f) / 100.0
    val bottomPct = ceil((1f - bottom.toFloat() / imageHeight) * 100f) / 100.0
    return "$topPct,$bottomPct"
  }
}