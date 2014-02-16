# -*- encoding: utf-8 -*-
$:.unshift File.expand_path("../lib", __FILE__)
$:.unshift File.expand_path("../../lib", __FILE__)

require 'yapper-sync/version'

Gem::Specification.new do |gem|
  gem.authors       = ["Kareem Kouddous"]
  gem.email         = ["kareemknyc@gmail.com"]
  gem.description   = "Sync extension for yapper"
  gem.summary       = "Sync extension for yapper"
  gem.homepage      = "https://github.com/kareemk/yapper-sync"

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "yapper-sync"
  gem.require_paths = ["lib"]
  gem.version       = Yapper::Sync::VERSION

  gem.add_dependency 'motion-support', '~> 0.2.4'
  gem.add_dependency 'motion-cocoapods', '~> 1.4.0'
  gem.add_dependency 'motion-logger', '~> 0.1.3'
  gem.add_dependency 'yapper', '~> 0.0.1'
  gem.add_development_dependency 'motion-redgreen'
  gem.add_development_dependency 'webstub'
end
