#
# Be sure to run `pod lib lint VideoPipelineKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'VideoPipelineKit'
  s.version          = '0.1.0'
  s.summary          = 'A SnapChat like video pipeline for rendering filters.'

  s.description      = <<-DESC
This framework builds a SnapChat like video pipeline for rendering filters.
                       DESC

  s.homepage         = 'https://github.com/OutThereLabs/VideoPipelineKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'pat2man' => 'pat2man@gmail.com' }
  s.source           = { :git => 'https://github.com/pat2man/VideoPipelineKit.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/pat2man'

  s.ios.deployment_target = '10.0'

  s.source_files = 'VideoPipelineKit/Classes/**/*'

  s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'Metal', 'QuartzCore', 'AVFoundation', 'UIKit'
end
