# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bbbevents/version"

Gem::Specification.new do |spec|
  spec.name          = "bbbevents"
  spec.version       = BBBEvents::VERSION
  spec.authors       = ["Joshua Arts"]
  spec.email         = ["joshua.rts@blindsidenetworks.com"]

  spec.summary       = %q{Easily parse data from a BigBlueButton recording's events.xml.}
  spec.description   = %q{Easily parse data from a BigBlueButton recording's events.xml.}
  spec.homepage      = "https://www.blindsidenetworks.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  
  # Gem dependecies.
  spec.add_dependency "nokogiri"
  spec.add_dependency "nori"
end
