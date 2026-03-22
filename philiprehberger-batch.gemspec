# frozen_string_literal: true

require_relative 'lib/philiprehberger/batch/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-batch'
  spec.version       = Philiprehberger::Batch::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Batch processing toolkit with chunking, progress, and error collection'
  spec.description   = 'Processes collections in configurable chunks with progress tracking callbacks ' \
                       'and per-item error collection. Returns detailed results including processed count, ' \
                       'error entries, chunk count, and elapsed time.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-batch'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
