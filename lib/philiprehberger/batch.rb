# frozen_string_literal: true

require_relative 'batch/version'
require_relative 'batch/chunk'
require_relative 'batch/result'
require_relative 'batch/processor'

module Philiprehberger
  module Batch
    class Error < StandardError; end

    # Process a collection in batches with chunking, progress, and error collection.
    #
    # @param collection [Array, Enumerable] items to process
    # @param size [Integer] chunk size
    # @param concurrency [Integer] number of concurrent workers
    # @param retries [Integer] max retries per failed item (default: 0)
    # @param on_progress [Proc, nil] optional callback invoked after each chunk with a progress info hash
    # @yield [chunk] block that receives a Chunk for processing
    # @return [Result] processing result
    def self.process(collection, size: 100, concurrency: 1, retries: 0, on_progress: nil, &block)
      processor = Processor.new(size: size, concurrency: concurrency, retries: retries)
      processor.call(collection, on_progress: on_progress, &block)
    end
  end
end
