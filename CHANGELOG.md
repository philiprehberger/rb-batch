# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0] - 2026-04-30

### Added
- `Result#failed_items` — unique list of items that errored, in first-failure order (deduplicates retried items)
- `Result#partial?` — true when some items succeeded and some errored; false on full success or full failure

## [0.8.0] - 2026-04-16

### Added
- `Result#filter_errors(error_class)` — returns array of `{ item:, error: }` hashes where the error is an instance of the given class
- `Result#errors_for(item)` — returns array of `{ item:, error: }` hashes for a specific item

## [0.7.0] - 2026-04-16

### Added
- `timeout_per_chunk:` option on `Batch.process` — when a chunk exceeds the timeout it is interrupted, a `Philiprehberger::Batch::TimeoutError` is appended to `Result#errors`, and processing continues with the next chunk
- `Philiprehberger::Batch::TimeoutError` error class (subclass of `Philiprehberger::Batch::Error`)

## [0.6.0] - 2026-04-15

### Added
- `Result#timing` — returns a hash of timing statistics: `total`, `per_chunk`, `per_item`, `fastest_chunk`, `slowest_chunk`

## [0.5.0] - 2026-04-15

### Added
- `Result#success_rate` — ratio of successfully processed items to total (Float in `[0.0, 1.0]`; returns `1.0` for empty batches)

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
