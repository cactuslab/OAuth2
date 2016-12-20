Pod::Spec.new do |s|
  s.name = 'OAuth2'
  s.version = '0.3.0'
  s.license = 'Apache License, Version 2.0'
  s.summary = 'OAuth2 frameworks for OS X and iOS written in Swift.'
  s.homepage = 'https://github.com/p2/OAuth2'
  s.authors = { 'Pascal Pfiffner' => '' }
  s.social_media_url = 'http://twitter.com/phaseofmatter'
  s.source = { :git => 'https://github.com/p2/OAuth2.git', :tag => '0.3.0' }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.9'

  s.source_files = 'OAuth2/*.swift'

  s.requires_arc = true
end
