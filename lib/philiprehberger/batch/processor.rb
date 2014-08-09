# frozen_string_literal: true

module Philiprehberger
  module Batch
    # Processes collections in chunks with progress tracking and error collection.
    class Processor
      # @param size [Integer] chunk size
      # @param concurrency [Integer] number of concurrent workers (reserved for future use)
      def initialize(size: 100, concurrency: 1)
        raise Error, 'size must be positive' unless size.is_a?(Integer) && size > 0

        @size = size
        @concurrency = concurrency
      end

      # Process a collection in batches.
      #
      # @param collection [Array, Enumerable] items to process
      # @yield [chunk] block that receives a Chunk object for processing
      # @return [Result] processing result
      def call(collection, &block)
        raise Error, 'a processing block is required' unless block

        items = collection.to_a
        chunks = items.each_slice(@size).to_a
        errors = []
        processed = 0
        start_time = now

        chunks.each_with_index do |slice, index|
          chunk = Chunk.new(items: slice, index: index)
          block.call(chunk)

          errors.concat(chunk.errors)
          processed += slice.size - chunk.errors.size

          notify_progress(chunk, index, chunks.size, processed, items.size)
        end

        Result.new(
          processed: processed,
          errors: errors,
          total: items.size,
          chunks: chunks.size,
          elapsed: now - start_time
        )
      end

      private

      def notify_progress(chunk, index, total_chunks, processed, total_items)
        return unless chunk.progress_callback

        chunk.progress_callback.call({
          chunk_index: index,
          total_chunks: total_chunks,
          processed: processed,
          total_items: total_items,
          percentage: total_items.zero? ? 100.0 : (processed.to_f / total_items * 100).round(1)
        })
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
