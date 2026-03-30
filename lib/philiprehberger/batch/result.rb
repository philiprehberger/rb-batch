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
      def initialize(processed:, errors:, total:, chunks:, elapsed:, halted: false, results: [])
        @processed = processed
        @errors = errors
        @total = total
        @chunks = chunks
        @elapsed = elapsed
        @halted = halted
        @results = results
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
      def each(&block)
        @results.each(&block)
      end

      # Map over all collected item results and flatten one level.
      #
      # @yield [item_result] each result value
      # @return [Array] flattened mapped results
      def flat_map(&block)
        @results.flat_map(&block)
      end

      # Count occurrences of each result value.
      #
      # @return [Hash] counts keyed by result value
      def counts
        @results.each_with_object(Hash.new(0)) do |item_result, hash|
          hash[item_result] += 1
        end
      end

      # Group results by the return value of the block.
      #
      # @yield [item_result] each result value
      # @return [Hash] grouped results
      def group_by(&block)
        @results.group_by(&block)
      end
    end
  end
end
