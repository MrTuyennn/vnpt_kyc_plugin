import UIKit

enum EkycIosBitmap {
  static func jpegFromData(_ data: Data) throws -> UIImage {
    guard let img = UIImage(data: data) else {
      throw NSError(domain: "ekyc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JPEG"])
    }
    return img
  }

  static func flipHorizontal(_ image: UIImage) -> UIImage {
    let src = upright(image)
    let renderer = UIGraphicsImageRenderer(size: src.size)
    return renderer.image { ctx in
      ctx.cgContext.translateBy(x: src.size.width, y: 0)
      ctx.cgContext.scaleBy(x: -1, y: 1)
      src.draw(in: CGRect(origin: .zero, size: src.size))
    }
  }

  static func upright(_ image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }

  static func scaleToPreviewHeight(_ image: UIImage, previewHeight: Int) -> UIImage {
    let upright = EkycIosBitmap.upright(image)
    let h = upright.size.height
    guard h > CGFloat(previewHeight) else { return upright }
    let scale = CGFloat(previewHeight) / h
    let newSize = CGSize(width: upright.size.width * scale, height: upright.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
      upright.draw(in: CGRect(origin: .zero, size: newSize))
    }
  }

  static func cropNormalized(
    _ image: UIImage,
    left: CGFloat,
    top: CGFloat,
    right: CGFloat,
    bottom: CGFloat
  ) -> UIImage {
    guard let cg = image.cgImage else { return image }
    let w = CGFloat(cg.width)
    let h = CGFloat(cg.height)
    let rect = CGRect(
      x: left * w,
      y: top * h,
      width: max(1, (right - left) * w),
      height: max(1, (bottom - top) * h)
    ).integral
    guard let cropped = cg.cropping(to: rect) else { return image }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
  }

  static func jpegData(_ image: UIImage, quality: CGFloat) -> Data? {
    image.jpegData(compressionQuality: quality)
  }

}