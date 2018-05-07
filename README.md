# philiprehberger-batch

[![Tests](https://github.com/philiprehberger/rb-batch/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-batch/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-batch.svg)](https://rubygems.org/gems/philiprehberger-batch)
[![GitHub release](https://img.shields.io/github/v/release/philiprehberger/rb-batch)](https://github.com/philiprehberger/rb-batch/releases)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-batch)](https://github.com/philiprehberger/rb-batch/commits/main)
[![License](https://img.shields.io/github/license/philiprehberger/rb-batch)](LICENSE)
[![Bug Reports](https://img.shields.io/github/issues/philiprehberger/rb-batch/bug)](https://github.com/philiprehberger/rb-batch/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Feature Requests](https://img.shields.io/github/issues/philiprehberger/rb-batch/enhancement)](https://github.com/philiprehberger/rb-batch/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
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

### Early Termination

```ruby
result = Philiprehberger::Batch.process(items, size: 50) do |batch|
  batch.on_error { |_item, _err| :halt }
  batch.each { |item| risky_operation(item) }
end

result.halted?  # => true if processing stopped early
```

### Retry Per Chunk

```ruby
result = Philiprehberger::Batch.process(items, size: 100, retries: 2) do |batch|
  batch.each { |item| unreliable_api_call(item) }
end
```

### Result Aggregation

```ruby
result = Philiprehberger::Batch.process(users, size: 50) do |batch|
  batch.each { |user| user.active? ? :active : :inactive }
end

result.counts                              # => { active: 42, inactive: 8 }
result.flat_map { |status| [status] }      # => [:active, :active, :inactive, ...]
result.group_by { |status| status }        # => { active: [...], inactive: [...] }
```

## API

| Method / Class | Description |
|--------|-------------|
| `.process(collection, size:, retries:) { \|batch\| }` | Process collection in chunks |
| `Chunk#each { \|item\| }` | Iterate over items in the chunk |
| `Chunk#on_progress { \|info\| }` | Register progress callback |
| `Chunk#on_error { \|item, err\| }` | Register error callback (return `:halt` to stop) |
| `Result#processed` | Number of successfully processed items |
| `Result#errors` | Array of error hashes |
| `Result#total` | Total number of items |
| `Result#chunks` | Number of chunks processed |
| `Result#elapsed` | Elapsed time in seconds |
| `Result#success?` | True if no errors occurred |
| `Result#halted?` | True if processing was halted early |
| `Result#results` | Array of collected return values |
| `Result#flat_map { \|r\| }` | Map over results and flatten |
| `Result#counts` | Hash counting occurrences of each result value |
| `Result#group_by { \|r\| }` | Group results by block return value |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this package useful, consider giving it a star on GitHub — it helps motivate continued maintenance and development.

[![LinkedIn](https://img.shields.io/badge/Philip%20Rehberger-LinkedIn-0A66C2?logo=linkedin)](https://www.linkedin.com/in/philiprehberger)
[![More packages](https://img.shields.io/badge/more-open%20source%20packages-blue)](https://philiprehberger.com/open-source-packages)

## License

[MIT](LICENSE)
