Pod::Spec.new do |s|
  s.name         = "GoSwift"
  s.version      = "1.0.0"
  s.summary      = "Go Goodies for Swift. Including goroutines, channels, defer, and panic."
  s.homepage     = "https://github.com/tidwall/GoSwift"
  s.license      = { :type => "Attribution License", :file => "LICENSE" }
  s.source       = { :git => "https://github.com/tidwall/GoSwift.git", :tag => "v#{s.version}" }
  s.authors      = { 'Josh Baker' => 'joshbaker77@gmail.com' }
  s.social_media_url   = "https://twitter.com/tidwall"
  s.ios.platform  = :ios, '8.0'
  s.ios.deployment_target = "8.0"
  s.osx.platform  = :osx, '10.9'
  s.osx.deployment_target = "10.9"
  s.source_files  = "GoSwift/go.swift"
  s.requires_arc = true
end
