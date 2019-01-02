# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails5/spec_converter/version'

Gem::Specification.new do |spec|
  spec.name          = "rr-to-rspec-converter"
  spec.version       = Rails5::SpecConverter::VERSION
  spec.authors       = ["Karl Varga"]
  spec.email         = ["kjvarga@gmail.com"]

  spec.summary       = %q{A tool to convert RR mocks/stubs to RSpec syntax}
  spec.description   = %q{Automatic conversion of RR mocks and stubs to modern RSpec syntax.}
  spec.homepage      = "https://github.com/kjvarga/rr-to-rspec-converter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'parser',        '>= 2.3.0.7'
  spec.add_runtime_dependency 'astrolabe',     '~> 1.2'

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "byebug"
end
