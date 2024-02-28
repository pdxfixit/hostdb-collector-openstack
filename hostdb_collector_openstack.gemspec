
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hostdb_collector_openstack/version"

Gem::Specification.new do |spec|
  spec.name          = "hostdb_collector_openstack"
  spec.version       = HostDBCollectorOpenstack::VERSION
  spec.authors       = ["PDXfixIT, LLC"]
  spec.email         = ["info@pdxfixit.com"]

  spec.summary       = %q{Library to query Openstack and insert current data about existing hosts into HostDB}
  spec.description   = "Gem capable of interacting with the dctool web service, the Openstack API, and the HostDB API to keep the VM information crispy"
  spec.homepage      = "https://github.com/pdxfixit/hostdb-collector-openstack"
  spec.license       = 'Nonstandard'

  spec.files         = Dir.glob("{bin,lib}/**/*")
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_dependency "excon"
end
