Pod::Spec.new do |s|
  s.name         = "ETPaginationRefreshControl"
  s.version      = "1.0.3"
  s.summary      = "Easy-to-use pagination refresh control."
  s.homepage     = "https://github.com/evgeniytka4enko/ETPaginationRefreshControl"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Evgeniy" => "evgeniytka4enko@gmail.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/evgeniytka4enko/ETPaginationRefreshControl.git", :tag => s.version.to_s }
  s.source_files = "Classes", "Classes/*.{h,m}"
  s.requires_arc = true
end
