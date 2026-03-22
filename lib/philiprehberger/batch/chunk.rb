# frozen_string_literal: true

module Philiprehberger
  module Batch
    # Represents a single chunk of items within a batch.
    class Chunk
      # @return [Array] items in this chunk
      attr_reader :items

      # @return [Integer] zero-based index of this chunk
      attr_reader :index

      # @param items [Array] items in this chunk
      # @param index [Integer] chunk index
      def initialize(items:, index:)
        @items = items
        @index = index
        @progress_callback = nil
        @error_callback = nil
      end

      # Iterate over items in the chunk.
      #
      # @yield [item] each item in the chunk
      # @return [void]
      def each(&block)
        @items.each(&block)
      end

      # Register a progress callback.
      #
      # @yield [info] called after the chunk is processed
      # @return [void]
      def on_progress(&block)
        @progress_callback = block
      end

      # Register an error callback.
      #
      # @yield [item, error] called when an item fails
      # @return [void]
      def on_error(&block)
        @error_callback = block
      end

      # @api private
      # @return [Proc, nil]
      attr_reader :progress_callback

      # @api private
      # @return [Proc, nil]
      attr_reader :error_callback
    end
  end
end
