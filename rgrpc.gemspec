lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rgrpc/version'

Gem::Specification.new do |spec|
  spec.name          = 'rgrpc'
  spec.version       = RGrpc::VERSION
  spec.authors       = ['Krisna Pranav']

  spec.summary       = 'gRPC for Ruby'
  spec.description   = 'gRPC for Ruby'
  spec.homepage      = 'https://github.com/krishpranav/rgRPC'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib', 'pb']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'

  spec.add_dependency 'grpc_kit', '>= 0.5.0'
  spec.add_dependency 'serverengine', '~> 2.0.7'
end