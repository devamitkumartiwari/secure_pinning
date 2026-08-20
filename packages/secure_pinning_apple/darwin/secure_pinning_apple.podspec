#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint secure_pinning_apple.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'secure_pinning_apple'
  s.version          = '0.0.1'
  s.summary          = 'iOS and macOS native probe-engine implementation for secure_pinning.'
  s.description      = <<-DESC
iOS and macOS native probe-engine implementation for secure_pinning, in one shared package built on Security.framework.
                       DESC
  s.homepage         = 'https://github.com/devamitkumartiwari/secure_pinning'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'therivanta' => 'noreply@therivanta.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'secure_pinning_apple/Sources/SecurePinningApple/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '16.0'
  s.osx.deployment_target = '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
