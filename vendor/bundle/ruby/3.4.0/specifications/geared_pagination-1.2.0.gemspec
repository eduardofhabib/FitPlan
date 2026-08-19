# -*- encoding: utf-8 -*-
# stub: geared_pagination 1.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "geared_pagination".freeze
  s.version = "1.2.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2023-11-28"
  s.email = "david@basecamp.com".freeze
  s.homepage = "https://github.com/basecamp/geared_pagination".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Paginate Active Record sets at variable speeds".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 5.0".freeze])
  s.add_runtime_dependency(%q<addressable>.freeze, [">= 2.5.0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0".freeze])
end
