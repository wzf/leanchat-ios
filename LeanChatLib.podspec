Pod::Spec.new do |s|
  s.name         = "LeanChatLib"
  s.version      = "0.1.3"
  s.summary      = "An IM App like WeChat App has to send text, pictures, audio, video, location messaging, managing address book, more interesting features."
  s.homepage     = "https://github.com/leancloud/leanchat-ios"
  s.license      = "MIT"
  s.authors      = { "LeanCloud" => "support@leancloud.cn" }
  s.source       = { :git => "https://github.com/leancloud/leanchat-ios.git", :tag => "0.1.3" }
  s.frameworks   = 'Foundation', 'CoreGraphics', 'UIKit', 'MobileCoreServices', 'AVFoundation', 'CoreLocation', 'MediaPlayer', 'CoreMedia', 'CoreText', 'AudioToolbox','MapKit','ImageIO','SystemConfiguration','CFNetwork','QuartzCore','Security','CoreTelephony'
  s.platform     = :ios, '7.0'
  s.source_files = 'LeanChatLib/Classes/**/*.{h,m}'
  s.resources    = 'LeanChatLib/Resources/*'
  s.libraries    = 'icucore','sqlite3'
  s.requires_arc = true
  s.dependency 'AVOSCloud'
  s.dependency 'AVOSCloudIM'
  s.dependency 'LZConversationCell', '~> 0.0.1'
  s.dependency 'DateTools' , '~> 1.5.0'
end
