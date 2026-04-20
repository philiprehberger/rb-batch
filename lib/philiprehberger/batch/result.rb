# frozen_string_literal: true

module Philiprehberger
  module Batch
    # Holds the outcome of a batch processing run.
    class Result
      include Enumerable

      # @return [Integer] number of items processed successfully
      attr_reader :processed

      # @return [Array<Hash>] errors with :item and :error keys
      attr_reader :errors

      # @return [Integer] total number of items
      attr_reader :total

      # @return [Integer] number of chunks processed
      attr_reader :chunks

      # @return [Float] elapsed time in seconds
      attr_reader :elapsed

      # @return [Array] results collected from each processed item
      attr_reader :results

      # @param processed [Integer] successfully processed count
      # @param errors [Array<Hash>] error entries
      # @param total [Integer] total item count
      # @param chunks [Integer] number of chunks
      # @param elapsed [Float] elapsed time
      # @param halted [Boolean] whether processing was halted early
      # @param results [Array] collected results from processing
      # @param chunk_times [Array<Float>] per-chunk elapsed durations
      def initialize(processed:, errors:, total:, chunks:, elapsed:, halted: false, results: [], chunk_times: [])
        @processed = processed
        @errors = errors
        @total = total
        @chunks = chunks
        @elapsed = elapsed
        @halted = halted
        @results = results
        @chunk_times = chunk_times
      end

      # Check if all items were processed without errors.
      #
      # @return [Boolean]
      def success?
        @errors.empty?
      end

      # Check if processing was halted early by an error handler returning :halt.
      #
      # @return [Boolean]
      def halted?
        @halted
      end

      # Iterate over all collected item results.
      #
      # @yield [item_result] each result value
      # @return [Enumerator] if no block given
      def each(&)
        @results.each(&)
      end

      # Map over all collected item results and flatten one level.
      #
      # @yield [item_result] each result value
      # @return [Array] flattened mapped results
      def flat_map(&)
        @results.flat_map(&)
      end

      # Count occurrences of each result value.
      #
      # @return [Hash] counts keyed by result value
      def counts
        @results.tally
      end

      # Group results by the return value of the block.
      #
      # @yield [item_result] each result value
      # @return [Hash] grouped results
      def group_by(&)
        @results.group_by(&)
      end

      # Ratio of successfully processed items to total items.
      #
      # Returns 1.0 for empty batches (no items to fail).
      #
      # @return [Float] value in the range [0.0, 1.0]
      def success_rate
        return 1.0 if @total.zero?

        @processed.to_f / @total
      end

      # Filter errors by error class.
      #
      # @param error_class [Class] the error class to filter by
      # @return [Array<Hash>] error entries where the error is an instance of the given class
      def filter_errors(error_class)
        @errors.select { |entry| entry[:error].is_a?(error_class) }
      end

      # Return all error entries for a specific item.
      #
      # @param item [Object] the item to look up
      # @return [Array<Hash>] error entries where the item matches
      def errors_for(item)
        @errors.select { |entry| entry[:item] == item }
      end

      # Timing statistics for the batch run.
      #
      # @return [Hash] timing breakdown with :total, :per_chunk, :per_item, :fastest_chunk, :slowest_chunk
      def timing
        if @chunk_times.empty?
          return {
            total: @elapsed,
            per_chunk: 0.0,
            per_item: 0.0,
            fastest_chunk: 0.0,
            slowest_chunk: 0.0
          }
        end

        {
          total: @elapsed,
          per_chunk: @elapsed / @chunk_times.size,
          per_item: @total.zero? ? 0.0 : @elapsed / @total,
          fastest_chunk: @chunk_times.min,
          slowest_chunk: @chunk_times.max
        }
      end
    end
  end
end
