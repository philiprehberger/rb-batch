# frozen_string_literal: true

module Philiprehberger
  module Batch
    # Represents a single chunk of items within a batch.
    class Chunk
      include Enumerable

      # @return [Array] items in this chunk
      attr_reader :items

      # @return [Integer] zero-based index of this chunk
      attr_reader :index

      # @param items [Array] items in this chunk
      # @param index [Integer] chunk index
      # @param retries [Integer] max retries for failed items
      def initialize(items:, index:, retries: 0)
        @items = items
        @index = index
        @retries = retries
        @progress_callback = nil
        @error_callback = nil
        @errors = []
        @results = []
        @halted = false
      end

      # @return [Array<Hash>] errors collected during iteration
      attr_reader :errors

      # @return [Array] results collected during iteration
      attr_reader :results

      # @return [Boolean] whether processing was halted by error handler
      def halted?
        @halted
      end

      # Iterate over items in the chunk, capturing errors per item.
      # Failed items are retried up to the configured number of retries
      # with exponential backoff. Only the failed items are retried.
      #
      # @yield [item] each item in the chunk
      # @return [void]
      def each(&block)
        @items.each do |item|
          break if @halted

          result = process_item_with_retries(item, &block)
          @results << result unless result == :__batch_error__
        end
      end

      # Register a progress callback.
      #
      # @yield [info] called after the chunk is processed
      # @return [void]
      def on_progress(&block)
        @progress_callback = block
      end

      # Register an error callback. If errors have already been collected,
      # the callback is invoked retroactively for each one.
      # Return :halt from the callback to stop processing remaining items.
      #
      # @yield [item, error] called when an item fails
      # @return [void]
      def on_error(&block)
        @error_callback = block
        @errors.each do |err|
          signal = block.call(err[:item], err[:error])
          if signal == :halt
            @halted = true
            break
          end
        end
      end

      # @api private
      # @return [Proc, nil]
      attr_reader :progress_callback

      # @api private
      # @return [Proc, nil]
      attr_reader :error_callback

      private

      def process_item_with_retries(item, &block)
        attempt = 0
        begin
          block.call(item)
        rescue StandardError => e
          if attempt < @retries
            attempt += 1
            sleep_for_backoff(attempt)
            retry
          end
          handle_error(item, e)
          :__batch_error__
        end
      end

      def handle_error(item, error)
        @errors << { item: item, error: error }
        signal = @error_callback&.call(item, error)
        @halted = true if signal == :halt
      end

      def sleep_for_backoff(attempt)
        sleep(2**(attempt - 1))
      end
    end
  end
end
