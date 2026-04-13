# frozen_string_literal: true

module Philiprehberger
  module Batch
    # Processes collections in chunks with progress tracking and error collection.
    class Processor
      # @param size [Integer] chunk size
      # @param concurrency [Integer] number of concurrent workers (default: 1)
      # @param retries [Integer] max retries per failed item (default: 0)
      def initialize(size: 100, concurrency: 1, retries: 0)
        raise Error, 'size must be positive' unless size.is_a?(Integer) && size.positive?
        raise Error, 'concurrency must be positive' unless concurrency.is_a?(Integer) && concurrency.positive?
        raise Error, 'retries must be non-negative' unless retries.is_a?(Integer) && retries >= 0

        @size = size
        @concurrency = concurrency
        @retries = retries
      end

      # Process a collection in batches.
      #
      # @param collection [Array, Enumerable] items to process
      # @yield [chunk] block that receives a Chunk object for processing
      # @return [Result] processing result
      def call(collection, &block)
        raise Error, 'a processing block is required' unless block

        items = collection.to_a
        slices = items.each_slice(@size).to_a

        if @concurrency > 1 && slices.size > 1
          call_concurrent(slices, items, &block)
        else
          call_sequential(slices, items, &block)
        end
      end

      private

      def call_sequential(slices, items, &block)
        errors = []
        results = []
        processed = 0
        halted = false
        chunks_processed = 0
        start_time = now

        slices.each_with_index do |slice, index|
          break if halted

          chunk = Chunk.new(items: slice, index: index, retries: @retries)
          block.call(chunk)

          errors.concat(chunk.errors)
          results.concat(chunk.results)
          processed += slice.size - chunk.errors.size
          chunks_processed += 1

          if chunk.halted?
            halted = true
          end

          notify_progress(chunk, index, slices.size, processed, items.size) unless halted
        end

        Result.new(
          processed: processed,
          errors: errors,
          total: items.size,
          chunks: chunks_processed,
          elapsed: now - start_time,
          halted: halted,
          results: results
        )
      end

      def call_concurrent(slices, items, &block)
        queue = Queue.new
        slices.each_with_index { |slice, index| queue << [slice, index] }

        workers = [@concurrency, slices.size].min
        mutex = Mutex.new
        halted = false
        chunk_slots = Array.new(slices.size)
        start_time = now

        threads = Array.new(workers) do
          Thread.new do
            loop do
              entry = begin
                queue.pop(true)
              rescue ThreadError
                nil
              end
              break unless entry

              slice, index = entry
              break if mutex.synchronize { halted }

              chunk = Chunk.new(items: slice, index: index, retries: @retries)
              block.call(chunk)

              mutex.synchronize do
                chunk_slots[index] = chunk
                halted = true if chunk.halted?
              end
            end
          end
        end

        threads.each(&:join)

        aggregate(chunk_slots, items.size, start_time)
      end

      def aggregate(chunk_slots, total_items, start_time)
        errors = []
        results = []
        processed = 0
        halted = false
        chunks_processed = 0

        chunk_slots.each do |chunk|
          next unless chunk

          errors.concat(chunk.errors)
          results.concat(chunk.results)
          processed += chunk.items.size - chunk.errors.size
          chunks_processed += 1
          halted = true if chunk.halted?
        end

        Result.new(
          processed: processed,
          errors: errors,
          total: total_items,
          chunks: chunks_processed,
          elapsed: now - start_time,
          halted: halted,
          results: results
        )
      end

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
