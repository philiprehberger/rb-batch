# frozen_string_literal: true

module Philiprehberger
  module Batch
    # Holds the outcome of a batch processing run.
    class Result
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

      # @param processed [Integer] successfully processed count
      # @param errors [Array<Hash>] error entries
      # @param total [Integer] total item count
      # @param chunks [Integer] number of chunks
      # @param elapsed [Float] elapsed time
      def initialize(processed:, errors:, total:, chunks:, elapsed:)
        @processed = processed
        @errors = errors
        @total = total
        @chunks = chunks
        @elapsed = elapsed
      end

      # Check if all items were processed without errors.
      #
      # @return [Boolean]
      def success?
        @errors.empty?
      end
    end
  end
end
