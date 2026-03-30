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

  describe 'early termination' do
    it 'halts processing when error handler returns :halt' do
      processed = []
      result = described_class.process((1..10).to_a, size: 2) do |batch|
        batch.on_error { |_item, _err| :halt }
        batch.each do |item|
          raise 'stop' if item == 3

          processed << item
        end
      end

      expect(result).to be_halted
      expect(processed).to include(1, 2)
      expect(processed).not_to include(4)
    end

    it 'does not process remaining chunks after halt' do
      chunks_seen = []
      result = described_class.process((1..10).to_a, size: 2) do |batch|
        chunks_seen << batch.index
        batch.on_error { |_item, _err| :halt }
        batch.each do |item|
          raise 'stop' if item == 1
        end
      end

      expect(result).to be_halted
      expect(chunks_seen).to eq([0])
    end

    it 'halted? returns false when not halted' do
      result = described_class.process([1, 2, 3], size: 3) do |batch|
        batch.each { |_| nil }
      end

      expect(result).not_to be_halted
    end

    it 'stops within a chunk when halt is signaled via on_error registered before each' do
      processed = []
      result = described_class.process([1, 2, 3, 4, 5], size: 5) do |batch|
        batch.on_error { |_item, _err| :halt }
        batch.each do |item|
          raise 'stop' if item == 3

          processed << item
        end
      end

      expect(result).to be_halted
      expect(processed).to eq([1, 2])
      expect(processed).not_to include(4, 5)
    end

    it 'does not halt when error handler returns something other than :halt' do
      result = described_class.process([1, 2, 3], size: 3) do |batch|
        batch.on_error { |_item, _err| :continue }
        batch.each do |item|
          raise 'fail' if item == 2
        end
      end

      expect(result).not_to be_halted
      expect(result.processed).to eq(2)
    end

    it 'remaining unprocessed items are not included in error counts' do
      result = described_class.process((1..10).to_a, size: 5) do |batch|
        batch.on_error { |_item, _err| :halt }
        batch.each do |item|
          raise 'stop' if item == 2
        end
      end

      expect(result.errors.size).to eq(1)
      expect(result.errors.first[:item]).to eq(2)
    end

    it 'halts via retroactive on_error callback after each' do
      processed = []
      result = described_class.process((1..6).to_a, size: 3) do |batch|
        batch.each do |item|
          raise 'fail' if item == 2

          processed << item
        end
        batch.on_error { |_item, _err| :halt }
      end

      expect(result).to be_halted
      expect(result.errors.size).to eq(1)
    end
  end

  describe 'retry per chunk' do
    it 'retries failed items up to the specified number of times' do
      attempts = Hash.new(0)
      result = described_class.process([1, 2, 3], size: 3, retries: 2) do |batch|
        batch.each do |item|
          attempts[item] += 1
          raise "fail #{item}" if item == 2 && attempts[item] <= 2
        end
      end

      expect(result).to be_success
      expect(attempts[2]).to eq(3) # initial + 2 retries
      expect(attempts[1]).to eq(1)
    end

    it 'records error after all retries are exhausted' do
      attempts = Hash.new(0)
      result = described_class.process([1], size: 1, retries: 2) do |batch|
        batch.each do |item|
          attempts[item] += 1
          raise 'always fails'
        end
      end

      expect(result.errors.size).to eq(1)
      expect(attempts[1]).to eq(3) # initial + 2 retries
    end

    it 'defaults to 0 retries (backward compatible)' do
      attempts = Hash.new(0)
      result = described_class.process([1], size: 1) do |batch|
        batch.each do |item|
          attempts[item] += 1
          raise 'fail'
        end
      end

      expect(attempts[1]).to eq(1)
      expect(result.errors.size).to eq(1)
    end

    it 'only retries failed items, not the whole chunk' do
      attempts = Hash.new(0)
      described_class.process([1, 2, 3], size: 3, retries: 1) do |batch|
        batch.each do |item|
          attempts[item] += 1
          raise 'fail' if item == 2
        end
      end

      expect(attempts[1]).to eq(1)
      expect(attempts[2]).to eq(2) # initial + 1 retry
      expect(attempts[3]).to eq(1)
    end

    it 'uses exponential backoff between retries' do
      sleep_calls = []
      chunk = Philiprehberger::Batch::Chunk.new(items: [1], index: 0, retries: 3)
      allow(chunk).to receive(:sleep) { |duration| sleep_calls << duration }

      chunk.each { |_| raise 'fail' }

      expect(sleep_calls).to eq([1, 2, 4]) # 2^0, 2^1, 2^2
    end

    it 'raises on negative retries' do
      expect { described_class.process([1], size: 1, retries: -1) { |b| b.each { |_| nil } } }
        .to raise_error(Philiprehberger::Batch::Error, /retries/)
    end
  end

  describe 'result aggregation' do
    it 'collects return values from each processed item' do
      result = described_class.process([1, 2, 3], size: 2) do |batch|
        batch.each { |item| item * 10 }
      end

      expect(result.results).to eq([10, 20, 30])
    end

    it 'flat_map maps over all results and flattens' do
      result = described_class.process([1, 2, 3], size: 2) do |batch|
        batch.each { |item| [item, item * 2] }
      end

      mapped = result.flat_map { |r| r }
      expect(mapped).to eq([1, 2, 2, 4, 3, 6])
    end

    it 'counts occurrences of each result value' do
      result = described_class.process(%w[a b a c b a], size: 3) do |batch|
        batch.each { |item| item }
      end

      expect(result.counts).to eq('a' => 3, 'b' => 2, 'c' => 1)
    end

    it 'group_by groups results by block return value' do
      result = described_class.process((1..6).to_a, size: 3) do |batch|
        batch.each { |item| item }
      end

      grouped = result.group_by { |r| r.even? ? :even : :odd }
      expect(grouped[:even]).to eq([2, 4, 6])
      expect(grouped[:odd]).to eq([1, 3, 5])
    end

    it 'does not include errored items in results' do
      result = described_class.process([1, 2, 3], size: 3) do |batch|
        batch.each do |item|
          raise 'fail' if item == 2

          item * 10
        end
      end

      expect(result.results).to eq([10, 30])
    end

    it 'results are empty for empty collection' do
      result = described_class.process([], size: 10) do |batch|
        batch.each { |item| item }
      end

      expect(result.results).to eq([])
      expect(result.counts).to eq({})
    end

    it 'is enumerable over results' do
      result = described_class.process([1, 2, 3], size: 3) do |batch|
        batch.each { |item| item * 2 }
      end

      expect(result.map { |r| r + 1 }).to eq([3, 5, 7])
      expect(result.select { |r| r > 3 }).to eq([4, 6])
    end

    it 'counts returns empty hash for empty results' do
      result = described_class.process([], size: 10) do |batch|
        batch.each { |item| item }
      end

      expect(result.counts).to eq({})
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

    it 'starts with empty results' do
      chunk = described_class.new(items: [1], index: 0)
      expect(chunk.results).to be_empty
    end

    it 'collects results from each' do
      chunk = described_class.new(items: [1, 2, 3], index: 0)
      chunk.each { |item| item * 2 }
      expect(chunk.results).to eq([2, 4, 6])
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

    it 'raises on negative retries' do
      expect { described_class.new(size: 1, retries: -1) }
        .to raise_error(Philiprehberger::Batch::Error, /retries/)
    end

    it 'raises on non-integer retries' do
      expect { described_class.new(size: 1, retries: 'abc') }
        .to raise_error(Philiprehberger::Batch::Error, /retries/)
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

    it 'defaults to not halted' do
      result = described_class.new(processed: 5, errors: [], total: 5, chunks: 1, elapsed: 0.1)
      expect(result).not_to be_halted
    end

    it 'reports halted when initialized as halted' do
      result = described_class.new(processed: 2, errors: [], total: 5, chunks: 1, elapsed: 0.1, halted: true)
      expect(result).to be_halted
    end

    it 'defaults to empty results' do
      result = described_class.new(processed: 0, errors: [], total: 0, chunks: 0, elapsed: 0.0)
      expect(result.results).to eq([])
    end

    it 'exposes results when provided' do
      result = described_class.new(processed: 3, errors: [], total: 3, chunks: 1, elapsed: 0.1,
                                   results: [10, 20, 30])
      expect(result.results).to eq([10, 20, 30])
    end
  end
end
