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
  end

  describe Philiprehberger::Batch::Chunk do
    it 'exposes items and index' do
      chunk = described_class.new(items: [1, 2, 3], index: 0)
      expect(chunk.items).to eq([1, 2, 3])
      expect(chunk.index).to eq(0)
    end

    it 'iterates over items' do
      chunk = described_class.new(items: %w[a b], index: 0)
      collected = []
      chunk.each { |item| collected << item }
      expect(collected).to eq(%w[a b])
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
  end
end
