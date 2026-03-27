# philiprehberger-batch

[![Tests](https://github.com/philiprehberger/rb-batch/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-batch/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-batch.svg)](https://rubygems.org/gems/philiprehberger-batch)
[![License](https://img.shields.io/github/license/philiprehberger/rb-batch)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Batch processing toolkit with chunking, progress, and error collection

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-batch"
```

Or install directly:

```bash
gem install philiprehberger-batch
```

## Usage

```ruby
require "philiprehberger/batch"

result = Philiprehberger::Batch.process(records, size: 50) do |batch|
  batch.each { |record| save(record) }
end

puts result.processed  # => number of successful items
puts result.success?   # => true if no errors
```

### Progress Tracking

```ruby
result = Philiprehberger::Batch.process(items, size: 100) do |batch|
  batch.each { |item| process(item) }
  batch.on_progress do |info|
    puts "Chunk #{info[:chunk_index] + 1}/#{info[:total_chunks]} - #{info[:percentage]}%"
  end
end
```

### Error Collection

```ruby
result = Philiprehberger::Batch.process(jobs, size: 25) do |batch|
  batch.each { |job| job.execute! }
  batch.on_error { |item, err| log_error(item, err) }
end

result.errors.each do |entry|
  puts "Failed: #{entry[:item]} - #{entry[:error].message}"
end
```

### Result Inspection

```ruby
result = Philiprehberger::Batch.process(data, size: 10) do |batch|
  batch.each { |item| transform(item) }
end

result.processed  # => successfully processed count
result.total      # => total item count
result.chunks     # => number of chunks processed
result.elapsed    # => processing time in seconds
result.errors     # => array of { item:, error: } hashes
result.success?   # => true if no errors
```

## API

| Method / Class | Description |
|--------|-------------|
| `.process(collection, size:, concurrency:) { \|batch\| }` | Process collection in chunks |
| `Chunk#each { \|item\| }` | Iterate over items in the chunk |
| `Chunk#on_progress { \|info\| }` | Register progress callback |
| `Chunk#on_error { \|item, err\| }` | Register error callback |
| `Result#processed` | Number of successfully processed items |
| `Result#errors` | Array of error hashes |
| `Result#total` | Total number of items |
| `Result#chunks` | Number of chunks processed |
| `Result#elapsed` | Elapsed time in seconds |
| `Result#success?` | True if no errors occurred |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
