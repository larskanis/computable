# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'computable/version'

Gem::Specification.new do |spec|
  spec.name          = "computable"
  spec.version       = Computable::VERSION
  spec.authors       = ["Lars Kanis"]
  spec.email         = ["lars@greiz-reinsdorf.de"]
  spec.description   = %q{Define computation tasks with automatic caching and dependency tracking.}
  spec.summary       = %q{Define computation tasks with automatic caching and dependency tracking.}
  spec.homepage      = "https://github.com/larskanis/computable"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.4", "< 4.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 5.6"
end
