#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint swift_ui.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'swiftui_kit'
  s.version          = '0.1.0'
  s.summary          = 'Native SwiftUI glass bars for Flutter.'
  s.description      = <<-DESC
A capsule bar and a title bar drawn by SwiftUI on iOS and macOS, with a
pure-Flutter fallback on every other platform.
                       DESC
  s.homepage         = 'https://github.com/longyi-0x0/swiftui_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'longyi' => 'dev@longyi.local' }
  s.source           = { :path => '.' }

  # Both platforms compile the same sources, kept in ../shared/swiftui_kit. The
  # directory listed here holds symlinks to them: CocoaPods refuses paths outside
  # the pod root, and SwiftPM refuses files outside the target directory, so
  # symlinks are the one form both accept.
  s.source_files = 'swiftui_kit/Sources/swiftui_kit/**/*.swift'

  s.dependency 'FlutterMacOS'

  # SF Symbols and `.ultraThinMaterial` both need at least this; the Liquid Glass
  # path is guarded by its own `#available` check.
  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
