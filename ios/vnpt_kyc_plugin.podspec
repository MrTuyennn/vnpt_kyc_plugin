Pod::Spec.new do |s|
  s.name             = 'vnpt_kyc_plugin'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin eKYC VNPT (SDK 2.0): quét CCCD, xác thực khuôn mặt 3D.'
  s.description      = <<-DESC
Plugin Flutter gộp engine eKYC của VNPT (eKYCLib.xcframework), xử lý ảnh và UI quét.
  DESC
  # TODO: thay homepage/author/license bằng thông tin thật của đơn vị phân phối.
  s.homepage         = 'https://example.com/TODO-vnpt-kyc-plugin'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = { 'TODO Author' => 'todo@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.vendored_frameworks = 'Frameworks/eKYCLib.xcframework'
  s.frameworks = 'UIKit', 'Foundation'
  s.swift_version = '5.0'
end
