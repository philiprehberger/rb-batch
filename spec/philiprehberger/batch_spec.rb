# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Batch do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::Batch::VERSION).not_to be_nil
    end
  end

  describe '.process' do
    it 'processes all items in chunks' do
      processed = []
      result = described_class.process((1..10).to_a, size: 3) do |batch|
        batch.each { |item| processed << item }
      end

      expect(processed).to eq((1..10).to_a)
      expect(result.processed).to eq(10)
      expect(result.total).to eq(10)
      expect(result.chunks).to eq(4) # 3+3+3+1
    end

    it 'returns a successful result when no errors' do
      result = described_class.process([1, 2, 3], size: 2) do |batch|
        batch.each { |_| nil }
      end

      expect(result).to be_success
      expect(result.errors).to be_empty
    end

    it 'raises when no block is given' do
      expect { described_class.process([1, 2]) }
        .to raise_error(Philiprehberger::Batch::Error, /block/)
    end

    it 'handles empty collection' do
      result = described_class.process([], size: 10) do |batch|
        batch.each { |_| nil }
      end

      expect(result.processed).to eq(0)
      expect(result.total).to eq(0)
      expect(result.chunks).to eq(0)
      expect(result).to be_success
    end

    it 'tracks elapsed time' do
      result = described_class.process([1], size: 1) do |batch|
        batch.each { |_| nil }
      end

      expect(result.elapsed).to be_a(Float)
      expect(result.elapsed).to be >= 0
    end

    it 'handles single item collection' do
      processed = []
      result = described_class.process([42], size: 10) do |batch|
        batch.each { |item| processed << item }
      end

      expect(processed).to eq([42])
      expect(result.processed).to eq(1)
      expect(result.total).to eq(1)
      expect(result.chunks).to eq(1)
    end

    it 'handles collection size equal to batch size' do
      result = described_class.process([1, 2, 3], size: 3) do |batch|
        batch.each { |_| nil }
      end

      expect(result.chunks).to eq(1)
      expect(result.processed).to eq(3)
    end

    it 'handles collection size smaller than batch size' do
      result = described_class.process([1, 2], size: 100) do |batch|
        batch.each { |_| nil }
      end

      expect(result.chunks).to eq(1)
      expect(result.processed).to eq(2)
    end

    it 'accepts an Enumerable (Range) as collection' do
      processed = []
      result = described_class.process(1..5, size: 2) do |batch|
        batch.each { |item| processed << item }
      end

      expect(processed).to eq([1, 2, 3, 4, 5])
      expect(result.total).to eq(5)
    end

    it 'processes items in order across chunks' do
      order = []
      described_class.process((1..9).to_a, size: 3) do |batch|
        batch.each { |item| order << item }
      end

      expect(order).to eq((1..9).to_a)
    end
  end

  describe 'progress tracking' do
    it 'calls on_progress callback for each chunk' do
      progress_reports = []
      described_class.process((1..6).to_a, size: 2) do |batch|
        batch.each { |_| nil }
        batch.on_progress { |info| progress_reports << info }
      end

      expect(progress_reports.size).to eq(3)
      expect(progress_reports.last[:processed]).to eq(6)
      expect(progress_reports.last[:total_items]).to eq(6)
      expect(progress_reports.last[:percentage]).to eq(100.0)
    end

    it 'includes chunk index in progress info' do
      indices = []
      described_class.process((1..4).to_a, size: 2) do |batch|
        batch.each { |_| nil }
        batch.on_progress { |info| indices << info[:chunk_index] }
      end

      expect(indices).to eq([0, 1])
    end

    it 'reports total_chunks in progress info' do
      total_chunks_values = []
      described_class.process((1..7).to_a, size: 3) do |batch|
        batch.each { |_| nil }
        batch.on_progress { |info| total_chunks_values << info[:total_chunks] }
      end

      expect(total_chunks_values).to all(eq(3))
    end

    it 'reports increasing processed counts' do
      processed_values = []
      described_class.process((1..6).to_a, size: 2) do |batch|
        batch.each { |_| nil }
        batch.on_progress { |info| processed_values << info[:processed] }
      end

      expect(processed_values).to eq([2, 4, 6])
    end

    it 'does not call progress when no callback registered' do
      # should not raise
      described_class.process([1, 2], size: 2) do |batch|
        batch.each { |_| nil }
      end
    end
  end

  describe 'error handling' do
    it 'collects errors and continues processing' do
      error_items = []
      result = described_class.process((1..5).to_a, size: 5) do |batch|
        batch.each do |item|
          raise "fail on #{item}" if item == 3
        end
        batch.on_error { |item, _err| error_items << item }
      end

      expect(result.errors.size).to eq(1)
      expect(result.errors.first[:item]).to eq(3)
      expect(result.processed).to eq(4)
      expect(error_items).to eq([3])
    end

    it 'marks result as not successful when errors exist' do
      result = described_class.process([1], size: 1) do |batch|
        batch.each { |_| raise 'boom' }
      end

      expect(result).not_to be_success
    end

    it 'collects multiple errors in a single chunk' do
      result = described_class.process([1, 2, 3], size: 3) do |batch|
        batch.each { |_| raise 'fail' }
      end

      expect(result.errors.size).to eq(3)
      expect(result.processed).to eq(0)
    end

    it 'collects errors across multiple chunks' do
      result = described_class.process([1, 2, 3, 4], size: 2) do |batch|
        batch.each { |item| raise 'fail' if item.even? }
      end

      expect(result.errors.size).to eq(2)
      expect(result.errors.map { |e| e[:item] }).to contain_exactly(2, 4)
      expect(result.processed).to eq(2)
    end

    it 'error entries contain both item and error' do
      result = described_class.process([1], size: 1) do |batch|
        batch.each { |_| raise 'specific error' }
      end

      entry = result.errors.first
      expect(entry[:item]).to eq(1)
      expect(entry[:error]).to be_a(RuntimeError)
      expect(entry[:error].message).to eq('specific error')
    end

    it 'invokes on_error callback for each failed item' do
      errors_seen = []
      described_class.process([1, 2, 3], size: 3) do |batch|
        batch.each { |item| raise "fail #{item}" if item.odd? }
        batch.on_error { |item, err| errors_seen << [item, err.message] }
      end

      expect(errors_seen).to contain_exactly([1, 'fail 1'], [3, 'fail 3'])
    end
  end

  describe Philiprehberger::Batch::Chunk do
    it 'exposes items and index' do
      chunk = described_class.new(items: [1, 2, 3], index: 0)
      expect(chunk.items).to eq([1, 2, 3])
      expect(chunk.index).to eq(0)
    end

    it 'iterates over items' do
      chunk = described_class.new(items: %w[a b], index: 0)
      collected = chunk.map { |item| item }
      expect(collected).to eq(%w[a b])
    end

    it 'starts with empty errors' do
      chunk = described_class.new(items: [1], index: 0)
      expect(chunk.errors).to be_empty
    end

    it 'starts with nil callbacks' do
      chunk = described_class.new(items: [1], index: 0)
      expect(chunk.progress_callback).to be_nil
      expect(chunk.error_callback).to be_nil
    end
  end

  describe Philiprehberger::Batch::Processor do
    it 'raises on non-positive size' do
      expect { described_class.new(size: 0) }
        .to raise_error(Philiprehberger::Batch::Error)
    end

    it 'raises on negative size' do
      expect { described_class.new(size: -1) }
        .to raise_error(Philiprehberger::Batch::Error)
    end

    it 'raises on non-integer size' do
      expect { described_class.new(size: 'abc') }
        .to raise_error(Philiprehberger::Batch::Error)
    end

    it 'raises on float size' do
      expect { described_class.new(size: 1.5) }
        .to raise_error(Philiprehberger::Batch::Error)
    end

    it 'accepts a size of 1' do
      processor = described_class.new(size: 1)
      result = processor.call([1, 2, 3]) { |batch| batch.each { |_| nil } }
      expect(result.chunks).to eq(3)
    end
  end

  describe Philiprehberger::Batch::Result do
    it 'reports success when no errors' do
      result = described_class.new(processed: 5, errors: [], total: 5, chunks: 1, elapsed: 0.1)
      expect(result).to be_success
    end

    it 'reports failure when errors exist' do
      result = described_class.new(processed: 4, errors: [{ item: 1, error: RuntimeError.new }], total: 5, chunks: 1,
                                   elapsed: 0.1)
      expect(result).not_to be_success
    end

    it 'exposes all attributes' do
      result = described_class.new(processed: 10, errors: [], total: 10, chunks: 2, elapsed: 1.5)
      expect(result.processed).to eq(10)
      expect(result.errors).to eq([])
      expect(result.total).to eq(10)
      expect(result.chunks).to eq(2)
      expect(result.elapsed).to eq(1.5)
    end
  end
end
