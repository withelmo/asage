
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "asage/version"

Gem::Specification.new do |spec|
  spec.name          = "asage"
  spec.version       = Asage::VERSION
  spec.authors       = ["withelmo"]
  spec.email         = ["withelmo@gmail.com"]

  spec.summary       = %q{Tool to control AWS auto scaling settings.}
  spec.description   = %q{auto-scaling-group, launch-config, AMI}
  spec.homepage      = "https://github.com/withelmo/asage"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry-byebug"

  spec.add_dependency "thor"
  spec.add_dependency "tty"
  spec.add_dependency "aws-sdk"
end
