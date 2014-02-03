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
    # @yield [chunk] block that receives a Chunk for processing
    # @return [Result] processing result
    def self.process(collection, size: 100, concurrency: 1, &block)
      processor = Processor.new(size: size, concurrency: concurrency)
      processor.call(collection, &block)
    end
  end
end
