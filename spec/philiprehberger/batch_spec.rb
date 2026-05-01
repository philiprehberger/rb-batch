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

    it 'provides timing statistics from process' do
      result = described_class.process((1..6).to_a, size: 2) do |batch|
        batch.each { |_| nil }
      end

      stats = result.timing
      expect(stats[:total]).to be_a(Float)
      expect(stats[:total]).to be >= 0
      expect(stats[:per_chunk]).to be_a(Float)
      expect(stats[:per_item]).to be_a(Float)
      expect(stats[:fastest_chunk]).to be_a(Float)
      expect(stats[:slowest_chunk]).to be_a(Float)
      expect(stats[:fastest_chunk]).to be <= stats[:slowest_chunk]
    end

    it 'provides timing statistics with concurrency' do
      result = described_class.process((1..6).to_a, size: 2, concurrency: 2) do |batch|
        batch.each { |_| nil }
      end

      stats = result.timing
      expect(stats[:total]).to be >= 0
      expect(stats[:fastest_chunk]).to be <= stats[:slowest_chunk]
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

  describe 'on_progress option' do
    it 'calls the top-level on_progress after each chunk' do
      reports = []
      described_class.process((1..6).to_a, size: 2, on_progress: ->(info) { reports << info }) do |batch|
        batch.each { |_| nil }
      end

      expect(reports.size).to eq(3)
      expect(reports.last[:processed]).to eq(6)
      expect(reports.last[:percentage]).to eq(100.0)
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

  describe 'timeout_per_chunk option' do
    it 'is backward compatible when timeout_per_chunk is nil (default)' do
      result = described_class.process([1, 2, 3], size: 2) do |batch|
        batch.each { |item| item }
      end

      expect(result).to be_success
      expect(result.processed).to eq(3)
    end

    it 'defines a TimeoutError subclass of Error' do
      expect(Philiprehberger::Batch::TimeoutError.ancestors).to include(Philiprehberger::Batch::Error)
    end

    it 'interrupts a chunk whose processing exceeds the timeout' do
      result = described_class.process([1, 2], size: 2, timeout_per_chunk: 0.05) do |batch|
        batch.each do |_item|
          sleep(0.5)
        end
      end

      expect(result.errors.size).to eq(1)
      expect(result.errors.first[:error]).to be_a(Philiprehberger::Batch::TimeoutError)
    end

    it 'does NOT count timed-out chunk items as processed' do
      result = described_class.process([1, 2, 3, 4], size: 2, timeout_per_chunk: 0.05) do |batch|
        batch.each do |item|
          sleep(0.5) if item == 1
        end
      end

      # First chunk [1, 2] times out -> not processed.
      # Second chunk [3, 4] should process normally.
      expect(result.processed).to eq(2)
    end

    it 'continues processing the next chunk after a timed-out chunk' do
      completed = []
      result = described_class.process([1, 2, 3, 4], size: 2, timeout_per_chunk: 0.05) do |batch|
        batch.each do |item|
          if item == 1
            sleep(0.5)
          else
            completed << item
          end
        end
      end

      expect(completed).to include(3, 4)
      expect(result.errors.size).to eq(1)
    end

    it 'records the chunk items in the error entry for a timeout' do
      result = described_class.process([1, 2, 3], size: 3, timeout_per_chunk: 0.05) do |batch|
        batch.each { |_| sleep(0.5) }
      end

      timeout_entry = result.errors.find { |e| e[:error].is_a?(Philiprehberger::Batch::TimeoutError) }
      expect(timeout_entry[:item]).to eq([1, 2, 3])
    end

    it 'raises when timeout_per_chunk is not positive' do
      expect { described_class.process([1], size: 1, timeout_per_chunk: 0) { |b| b.each { |_| nil } } }
        .to raise_error(Philiprehberger::Batch::Error, /timeout_per_chunk/)
    end

    it 'raises when timeout_per_chunk is not numeric' do
      expect { described_class.process([1], size: 1, timeout_per_chunk: 'abc') { |b| b.each { |_| nil } } }
        .to raise_error(Philiprehberger::Batch::Error, /timeout_per_chunk/)
    end
  end

  describe 'concurrency' do
    it 'processes all items with concurrency > 1' do
      processed = Mutex.new
      collected = []
      result = described_class.process((1..12).to_a, size: 3, concurrency: 3) do |batch|
        batch.each do |item|
          processed.synchronize { collected << item }
        end
      end

      expect(collected.sort).to eq((1..12).to_a)
      expect(result.processed).to eq(12)
      expect(result.total).to eq(12)
      expect(result.chunks).to eq(4)
    end

    it 'collects results in chunk order' do
      result = described_class.process((1..6).to_a, size: 2, concurrency: 3) do |batch|
        batch.each { |item| item * 10 }
      end

      expect(result.results).to eq([10, 20, 30, 40, 50, 60])
    end

    it 'collects errors across concurrent chunks' do
      result = described_class.process((1..6).to_a, size: 2, concurrency: 2) do |batch|
        batch.each { |item| raise "fail #{item}" if item.even? }
      end

      expect(result.errors.size).to eq(3)
      expect(result.errors.map { |e| e[:item] }.sort).to eq([2, 4, 6])
      expect(result.processed).to eq(3)
    end

    it 'halts stops remaining chunks' do
      result = described_class.process((1..20).to_a, size: 1, concurrency: 2) do |batch|
        batch.on_error { |_item, _err| :halt }
        batch.each do |item|
          raise 'stop' if item == 1
        end
      end

      expect(result).to be_halted
      expect(result.chunks).to be < 20
    end

    it 'falls back to sequential when only one chunk' do
      result = described_class.process([1, 2, 3], size: 10, concurrency: 4) do |batch|
        batch.each { |item| item }
      end

      expect(result.results).to eq([1, 2, 3])
      expect(result.chunks).to eq(1)
    end

    it 'handles concurrency larger than number of chunks' do
      result = described_class.process((1..4).to_a, size: 2, concurrency: 10) do |batch|
        batch.each { |item| item }
      end

      expect(result.results).to eq([1, 2, 3, 4])
      expect(result.chunks).to eq(2)
    end

    it 'concurrency 1 behaves identically to sequential' do
      sequential = described_class.process((1..6).to_a, size: 2) do |batch|
        batch.each { |item| item * 2 }
      end

      concurrent = described_class.process((1..6).to_a, size: 2, concurrency: 1) do |batch|
        batch.each { |item| item * 2 }
      end

      expect(concurrent.results).to eq(sequential.results)
      expect(concurrent.processed).to eq(sequential.processed)
      expect(concurrent.chunks).to eq(sequential.chunks)
    end

    it 'validates concurrency is a positive integer' do
      expect { described_class.process([1], size: 1, concurrency: 0) { |b| b.each { |_| nil } } }
        .to raise_error(Philiprehberger::Batch::Error, /concurrency/)
    end

    it 'validates concurrency is not negative' do
      expect { described_class.process([1], size: 1, concurrency: -1) { |b| b.each { |_| nil } } }
        .to raise_error(Philiprehberger::Batch::Error, /concurrency/)
    end

    it 'validates concurrency is an integer' do
      expect { described_class.process([1], size: 1, concurrency: 'abc') { |b| b.each { |_| nil } } }
        .to raise_error(Philiprehberger::Batch::Error, /concurrency/)
    end

    it 'tracks elapsed time with concurrency' do
      result = described_class.process((1..4).to_a, size: 2, concurrency: 2) do |batch|
        batch.each { |_| nil }
      end

      expect(result.elapsed).to be_a(Float)
      expect(result.elapsed).to be >= 0
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

    it 'raises on zero concurrency' do
      expect { described_class.new(size: 1, concurrency: 0) }
        .to raise_error(Philiprehberger::Batch::Error, /concurrency/)
    end

    it 'raises on non-integer concurrency' do
      expect { described_class.new(size: 1, concurrency: 1.5) }
        .to raise_error(Philiprehberger::Batch::Error, /concurrency/)
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

    describe '#timing' do
      it 'returns a hash with all timing keys' do
        result = described_class.new(processed: 6, errors: [], total: 6, chunks: 3, elapsed: 0.9,
                                     chunk_times: [0.2, 0.3, 0.4])
        stats = result.timing

        expect(stats).to be_a(Hash)
        expect(stats.keys).to contain_exactly(:total, :per_chunk, :per_item, :fastest_chunk, :slowest_chunk)
      end

      it 'returns total equal to elapsed' do
        result = described_class.new(processed: 4, errors: [], total: 4, chunks: 2, elapsed: 1.0,
                                     chunk_times: [0.4, 0.6])
        expect(result.timing[:total]).to eq(1.0)
      end

      it 'calculates per_chunk as elapsed / number of chunks' do
        result = described_class.new(processed: 6, errors: [], total: 6, chunks: 3, elapsed: 0.9,
                                     chunk_times: [0.2, 0.3, 0.4])
        expect(result.timing[:per_chunk]).to be_within(0.0001).of(0.3)
      end

      it 'calculates per_item as elapsed / total items' do
        result = described_class.new(processed: 4, errors: [], total: 8, chunks: 2, elapsed: 2.0,
                                     chunk_times: [0.8, 1.2])
        expect(result.timing[:per_item]).to eq(0.25)
      end

      it 'returns fastest and slowest chunk times' do
        result = described_class.new(processed: 6, errors: [], total: 6, chunks: 3, elapsed: 1.5,
                                     chunk_times: [0.3, 0.5, 0.7])
        expect(result.timing[:fastest_chunk]).to eq(0.3)
        expect(result.timing[:slowest_chunk]).to eq(0.7)
      end

      it 'returns zeros when no chunks were processed' do
        result = described_class.new(processed: 0, errors: [], total: 0, chunks: 0, elapsed: 0.0)
        stats = result.timing

        expect(stats[:total]).to eq(0.0)
        expect(stats[:per_chunk]).to eq(0.0)
        expect(stats[:per_item]).to eq(0.0)
        expect(stats[:fastest_chunk]).to eq(0.0)
        expect(stats[:slowest_chunk]).to eq(0.0)
      end

      it 'handles a single chunk' do
        result = described_class.new(processed: 3, errors: [], total: 3, chunks: 1, elapsed: 0.5,
                                     chunk_times: [0.5])
        stats = result.timing

        expect(stats[:per_chunk]).to eq(0.5)
        expect(stats[:fastest_chunk]).to eq(0.5)
        expect(stats[:slowest_chunk]).to eq(0.5)
      end

      it 'returns per_item as 0.0 when total is zero' do
        result = described_class.new(processed: 0, errors: [], total: 0, chunks: 0, elapsed: 0.0,
                                     chunk_times: [])
        expect(result.timing[:per_item]).to eq(0.0)
      end
    end

    describe '#success_rate' do
      it 'returns 1.0 when all items succeed' do
        result = described_class.new(processed: 5, errors: [], total: 5, chunks: 1, elapsed: 0.1)
        expect(result.success_rate).to eq(1.0)
      end

      it 'returns 0.5 when half the items fail' do
        errors = Array.new(2) { { item: nil, error: RuntimeError.new } }
        result = described_class.new(processed: 2, errors: errors, total: 4, chunks: 1, elapsed: 0.1)
        expect(result.success_rate).to eq(0.5)
      end

      it 'returns 0.0 when all items fail' do
        errors = Array.new(3) { { item: nil, error: RuntimeError.new } }
        result = described_class.new(processed: 0, errors: errors, total: 3, chunks: 1, elapsed: 0.1)
        expect(result.success_rate).to eq(0.0)
      end

      it 'returns 1.0 for an empty batch' do
        result = described_class.new(processed: 0, errors: [], total: 0, chunks: 0, elapsed: 0.0)
        expect(result.success_rate).to eq(1.0)
      end

      it 'returns a Float in [0.0, 1.0]' do
        result = described_class.new(processed: 1, errors: [{ item: nil, error: RuntimeError.new }],
                                     total: 3, chunks: 1, elapsed: 0.1)
        expect(result.success_rate).to be_a(Float)
        expect(result.success_rate).to be_between(0.0, 1.0).inclusive
      end
    end

    describe '#filter_errors' do
      it 'returns error entries matching the given error class' do
        arg_err = ArgumentError.new('bad arg')
        runtime_err = RuntimeError.new('boom')
        errors = [{ item: 1, error: arg_err }, { item: 2, error: runtime_err }]
        result = described_class.new(processed: 0, errors: errors, total: 2, chunks: 1, elapsed: 0.1)

        filtered = result.filter_errors(ArgumentError)
        expect(filtered.size).to eq(1)
        expect(filtered.first[:item]).to eq(1)
        expect(filtered.first[:error]).to be(arg_err)
      end

      it 'returns an empty array when no errors match the class' do
        errors = [{ item: 1, error: RuntimeError.new('boom') }]
        result = described_class.new(processed: 0, errors: errors, total: 1, chunks: 1, elapsed: 0.1)

        expect(result.filter_errors(ArgumentError)).to eq([])
      end

      it 'returns all matching entries when multiple errors share the class' do
        errors = [
          { item: 1, error: ArgumentError.new('first') },
          { item: 2, error: RuntimeError.new('other') },
          { item: 3, error: ArgumentError.new('second') }
        ]
        result = described_class.new(processed: 0, errors: errors, total: 3, chunks: 1, elapsed: 0.1)

        filtered = result.filter_errors(ArgumentError)
        expect(filtered.size).to eq(2)
        expect(filtered.map { |e| e[:item] }).to contain_exactly(1, 3)
      end

      it 'returns an empty array when there are no errors' do
        result = described_class.new(processed: 3, errors: [], total: 3, chunks: 1, elapsed: 0.1)
        expect(result.filter_errors(RuntimeError)).to eq([])
      end

      it 'matches subclass instances when filtering by superclass' do
        timeout_err = Philiprehberger::Batch::TimeoutError.new('timed out')
        errors = [{ item: [1, 2], error: timeout_err }]
        result = described_class.new(processed: 0, errors: errors, total: 2, chunks: 1, elapsed: 0.1)

        expect(result.filter_errors(Philiprehberger::Batch::Error).size).to eq(1)
        expect(result.filter_errors(Philiprehberger::Batch::TimeoutError).size).to eq(1)
      end
    end

    describe '#errors_for' do
      it 'returns error entries for the specified item' do
        err = RuntimeError.new('boom')
        errors = [{ item: 'a', error: err }, { item: 'b', error: RuntimeError.new('other') }]
        result = described_class.new(processed: 0, errors: errors, total: 2, chunks: 1, elapsed: 0.1)

        found = result.errors_for('a')
        expect(found.size).to eq(1)
        expect(found.first[:item]).to eq('a')
        expect(found.first[:error]).to be(err)
      end

      it 'returns an empty array when no errors match the item' do
        errors = [{ item: 1, error: RuntimeError.new('boom') }]
        result = described_class.new(processed: 0, errors: errors, total: 1, chunks: 1, elapsed: 0.1)

        expect(result.errors_for(99)).to eq([])
      end

      it 'returns multiple entries when the same item appears more than once' do
        err1 = RuntimeError.new('first')
        err2 = ArgumentError.new('second')
        errors = [
          { item: 42, error: err1 },
          { item: 7, error: RuntimeError.new('other') },
          { item: 42, error: err2 }
        ]
        result = described_class.new(processed: 0, errors: errors, total: 3, chunks: 1, elapsed: 0.1)

        found = result.errors_for(42)
        expect(found.size).to eq(2)
        expect(found.map { |e| e[:error] }).to contain_exactly(err1, err2)
      end

      it 'returns an empty array when there are no errors' do
        result = described_class.new(processed: 3, errors: [], total: 3, chunks: 1, elapsed: 0.1)
        expect(result.errors_for(1)).to eq([])
      end
    end

    describe '#failed_items' do
      it 'returns the unique items that errored' do
        errors = [
          { item: 'a', error: RuntimeError.new('boom') },
          { item: 'b', error: RuntimeError.new('boom') },
          { item: 'a', error: ArgumentError.new('retry') }
        ]
        result = described_class.new(processed: 1, errors: errors, total: 4, chunks: 1, elapsed: 0.1)

        expect(result.failed_items).to eq(%w[a b])
      end

      it 'returns an empty array when there are no errors' do
        result = described_class.new(processed: 3, errors: [], total: 3, chunks: 1, elapsed: 0.1)
        expect(result.failed_items).to eq([])
      end
    end

    describe '#partial?' do
      it 'is true when some items succeeded and some errored' do
        errors = [{ item: 'a', error: RuntimeError.new('boom') }]
        result = described_class.new(processed: 2, errors: errors, total: 3, chunks: 1, elapsed: 0.1)
        expect(result.partial?).to be(true)
      end

      it 'is false on full success' do
        result = described_class.new(processed: 3, errors: [], total: 3, chunks: 1, elapsed: 0.1)
        expect(result.partial?).to be(false)
      end

      it 'is false when every item failed' do
        errors = [{ item: 'a', error: RuntimeError.new('boom') }]
        result = described_class.new(processed: 0, errors: errors, total: 1, chunks: 1, elapsed: 0.1)
        expect(result.partial?).to be(false)
      end
    end
  end
end
