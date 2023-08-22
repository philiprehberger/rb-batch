# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-04-15

### Added
- `on_progress:` option on `Batch.process` — invoked after each chunk with a progress info hash

## [0.3.0] - 2026-04-12

### Added
- Thread-based concurrent chunk processing via `concurrency:` parameter
- Validate `concurrency` must be a positive integer

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-29

### Added
- Early termination via error handler returning `:halt` to stop processing remaining chunks
- `Result#halted?` to check if processing was halted early
- Retry per chunk with `retries:` parameter and exponential backoff
- Only failed items within a chunk are retried, not the whole chunk
- `Result#results` collects return values from each processed item
- `Result#flat_map` to map over all results and flatten one level
- `Result#counts` to count occurrences of each result value
- `Result#group_by` to group results by block return value
- Result is now Enumerable over collected item results

## [0.1.2] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.1] - 2026-03-22

### Changed
- Expand test coverage

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Batch processing with configurable chunk size
- Progress tracking callbacks with percentage and counts
- Per-item error collection with continuation
- Result object with processed count, errors, chunks, and elapsed time
- Chunk object with items, index, and callback registration
