# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  root = File.dirname(__FILE__)

  s.name     = 'ublisherp'
  s.version  = '0.0.1'
  s.authors  = ['Dan Brown', 'Alex Barlow']
  s.email    = ['dan@madebymany.co.uk', 'alexb@madebymany.co.uk']
  s.summary  = 'Publisher from ActiveRecord to Redis'
  s.homepage = 'https://github.com/madebymany/ublisherp'

  s.files         = Dir[File.join(root, 'lib/**/*.rb')]
  s.test_files    = Dir[File.join(root, 'spec/**/*.rb')]
  s.require_paths = ['lib']

  s.add_runtime_dependency 'redis', '>= 2.2.2'
  s.add_runtime_dependency 'redis-namespace'
  s.add_runtime_dependency 'activesupport', '>= 3.2'
  s.add_runtime_dependency 'activemodel', '>= 3.2', '< 5'
  s.add_runtime_dependency 'multi_json', '~> 1.0'
  s.add_runtime_dependency 'oj', '~> 2.0.11'
  s.add_runtime_dependency 'hooks', '~> 0.3.1'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'activerecord',  '~> 3.2'
end
