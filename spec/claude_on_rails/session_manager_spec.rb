# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'claude_on_rails/session_manager'

RSpec.describe ClaudeOnRails::SessionManager do
  let(:tmpdir) { Dir.mktmpdir }
  let(:sessions_dir) { File.join(tmpdir, '.claude-swarm') }
  let(:manager) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  def create_session(name, age_days: 0, file_content: 'x' * 1024)
    dir = File.join(sessions_dir, name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'session.json'), file_content)
    # Set mtime to simulate age
    target_time = Time.now - (age_days * 86_400)
    FileUtils.touch(dir, mtime: target_time)
    dir
  end

  describe '#sessions' do
    it 'returns empty array when no sessions exist' do
      expect(manager.sessions).to eq([])
    end

    it 'returns empty array when directory does not exist' do
      manager_no_dir = described_class.new('/nonexistent/path')
      expect(manager_no_dir.sessions).to eq([])
    end

    it 'lists sessions from .claude-swarm directory' do
      create_session('session_abc123')
      create_session('session_def456')

      result = manager.sessions
      expect(result.length).to eq(2)
      names = result.map { |s| s[:name] }
      expect(names).to include('session_abc123', 'session_def456')
    end

    it 'sorts by date with newest first' do
      create_session('session_old', age_days: 5)
      create_session('session_new', age_days: 0)
      create_session('session_mid', age_days: 2)

      result = manager.sessions
      expect(result.map { |s| s[:name] }).to eq(%w[session_new session_mid session_old])
    end

    it 'includes path, name, date, and size_bytes in each session hash' do
      create_session('session_abc123')

      result = manager.sessions.first
      expect(result).to have_key(:path)
      expect(result).to have_key(:name)
      expect(result).to have_key(:date)
      expect(result).to have_key(:size_bytes)
      expect(result[:name]).to eq('session_abc123')
      expect(result[:date]).to be_a(Time)
      expect(result[:size_bytes]).to be > 0
    end

    it 'ignores regular files in sessions directory' do
      FileUtils.mkdir_p(sessions_dir)
      File.write(File.join(sessions_dir, 'some_file.txt'), 'not a session')

      expect(manager.sessions).to eq([])
    end
  end

  describe '#total_size' do
    it 'returns zero when no sessions exist' do
      expect(manager.total_size).to eq(0)
    end

    it 'calculates total size across all sessions' do
      create_session('session_a', file_content: 'x' * 500)
      create_session('session_b', file_content: 'y' * 300)

      expect(manager.total_size).to eq(800)
    end
  end

  describe '#cleanup' do
    it 'keeps N most recent sessions and removes the rest' do
      create_session('session_old', age_days: 10)
      create_session('session_mid', age_days: 5)
      create_session('session_new', age_days: 0)

      removed = manager.cleanup(keep: 2)

      expect(removed).to eq(1)
      remaining = manager.sessions.map { |s| s[:name] }
      expect(remaining).to eq(%w[session_new session_mid])
      expect(Dir.exist?(File.join(sessions_dir, 'session_old'))).to be false
    end

    it 'returns 0 when there are fewer sessions than keep count' do
      create_session('session_a')

      expect(manager.cleanup(keep: 5)).to eq(0)
    end

    it 'returns count of removed sessions' do
      create_session('session_1', age_days: 10)
      create_session('session_2', age_days: 8)
      create_session('session_3', age_days: 6)
      create_session('session_4', age_days: 4)
      create_session('session_5', age_days: 2)

      removed = manager.cleanup(keep: 2)
      expect(removed).to eq(3)
    end
  end

  describe '#cleanup_older_than' do
    it 'removes sessions older than N days' do
      create_session('session_old', age_days: 10)
      create_session('session_recent', age_days: 1)

      removed = manager.cleanup_older_than(days: 5)

      expect(removed).to eq(1)
      remaining = manager.sessions.map { |s| s[:name] }
      expect(remaining).to eq(%w[session_recent])
    end

    it 'returns count of removed sessions' do
      create_session('session_a', age_days: 20)
      create_session('session_b', age_days: 15)
      create_session('session_c', age_days: 1)

      expect(manager.cleanup_older_than(days: 7)).to eq(2)
    end

    it 'returns 0 when no sessions are old enough' do
      create_session('session_new', age_days: 1)

      expect(manager.cleanup_older_than(days: 30)).to eq(0)
    end
  end

  describe '#format_size' do
    it 'formats bytes' do
      expect(manager.format_size(500)).to eq('500 B')
    end

    it 'formats kilobytes' do
      expect(manager.format_size(2048)).to eq('2.0 KB')
    end

    it 'formats megabytes' do
      expect(manager.format_size(2_621_440)).to eq('2.5 MB')
    end
  end
end
