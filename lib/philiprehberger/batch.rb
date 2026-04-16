# frozen_string_literal: true

require_relative 'batch/version'
require_relative 'batch/chunk'
require_relative 'batch/result'
require_relative 'batch/processor'

module Philiprehberger
  module Batch
    class Error < StandardError; end

    # Raised when a chunk exceeds the configured +timeout_per_chunk+.
    # Captured as an entry in the resulting +Result#errors+ array — not propagated
    # to the caller — so processing continues with the next chunk.
    class TimeoutError < Error; end

    # Process a collection in batches with chunking, progress, and error collection.
    #
    # @param collection [Array, Enumerable] items to process
    # @param size [Integer] chunk size
    # @param concurrency [Integer] number of concurrent workers
    # @param retries [Integer] max retries per failed item (default: 0)
    # @param timeout_per_chunk [Numeric, nil] optional per-chunk timeout in seconds;
    #   when a chunk exceeds it, a {TimeoutError} is appended to +Result#errors+ and
    #   processing continues with the next chunk
    # @param on_progress [Proc, nil] optional callback invoked after each chunk with a progress info hash
    # @yield [chunk] block that receives a Chunk for processing
    # @return [Result] processing result
    def self.process(collection, size: 100, concurrency: 1, retries: 0,
                     timeout_per_chunk: nil, on_progress: nil, &block)
      processor = Processor.new(
        size: size,
        concurrency: concurrency,
        retries: retries,
        timeout_per_chunk: timeout_per_chunk
      )
      processor.call(collection, on_progress: on_progress, &block)
    end
  end
end
