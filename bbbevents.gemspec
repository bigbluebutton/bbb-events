# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bbbevents/version"

Gem::Specification.new do |spec|
  spec.name          = "bbbevents"
  spec.version       = BBBEvents::VERSION
  spec.authors       = ["Blindside Networks"]
  spec.email         = ["ffdixon@blindsidenetworks.com"]

  spec.summary       = %q{Easily parse data from a BigBlueButton recording's events.xml.}
  spec.description   = %q{Ruby gem for easily parse data from a BigBlueButton recording's events.xml.}
  spec.homepage      = "https://www.blindsidenetworks.com"
  spec.license       = "LGPL-3.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.4"

  # Gem dependecies.
  spec.add_dependency 'activesupport', '>= 5.0.0.1', '< 7'

end
