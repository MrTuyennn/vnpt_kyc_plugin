import UIKit

enum EkycOvalGeometry {
  struct PreviewSize {
    let width: Int
    let height: Int
  }

  static func cropForEngine(
    image: UIImage,
    preview: PreviewSize,
    isFar: Bool
  ) throws -> UIImage {
    guard let pixels = image.cgImage else { throw invalidCrop() }
    let width = CGFloat(pixels.width)
    let height = CGFloat(pixels.height)
    let viewportAspect = CGFloat(preview.width) / CGFloat(preview.height)

    // The texture is center-cropped to the same portrait viewport in Flutter.
    let visibleWidth = min(width, height * viewportAspect)
    let visibleHeight = min(height, width / viewportAspect)

    // ICSdkEKYC 3.7.1 builds a centered crop before processWithBmp. The iPhone
    // near step scales the far crop by 1.5 on X and 1.75 on Y.
    let cropWidth = visibleWidth * (isFar ? 0.5 : 0.5 * 1.5)
    let cropHeight = visibleHeight * (isFar ? 0.5625 : 0.5625 * 1.75)
    let rect = CGRect(
      x: (width - cropWidth) / 2,
      y: (height - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight
    ).integral
    guard let cropped = pixels.cropping(to: rect) else { throw invalidCrop() }
    return UIImage(cgImage: cropped)
  }

  private static func invalidCrop() -> NSError {
    NSError(domain: "FACE", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid oval crop"])
  }
}
