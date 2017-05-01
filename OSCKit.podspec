Pod::Spec.new do |s|

  s.name         = "OSCKit"
  s.version      = "0.0.1"
  s.summary      = "Richo OSCKit"
  s.description  = "Richo OSCKit with Promise"
  s.homepage     = "https://theta360.com/"
  s.license      = "MIT"
  s.author       = { "Zhigang Fang" => "zhigang1992@gmail.com" }
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/tappollo/OSCKit.git", :tag => :tag => s.version }
  s.source_files  = "Source/*.swift"
  s.frameworks = "SystemConfiguration"
  s.dependency 'SwiftyyJSON'
  s.dependency 'PromiseKit'
  s.dependency 'AwaitKit'
end
