# frozen_string_literal: true

require 'fileutils'

module ClaudeOnRails
  # Manages claude-swarm session data stored in .claude-swarm/ directory
  class SessionManager
    attr_reader :root_path, :sessions_dir

    def initialize(root_path)
      @root_path = root_path
      @sessions_dir = File.join(root_path, '.claude-swarm')
    end

    def sessions
      return [] unless Dir.exist?(sessions_dir)

      entries = Dir.entries(sessions_dir) - %w[. ..]
      entries.filter_map { |name| build_session_info(name) }
             .sort_by { |s| s[:date] }
             .reverse
    end

    def total_size
      sessions.sum { |s| s[:size_bytes] }
    end

    def cleanup(keep: 5)
      all_sessions = sessions
      return 0 if all_sessions.length <= keep

      to_remove = all_sessions[keep..]
      to_remove.each { |s| FileUtils.rm_rf(s[:path]) }
      to_remove.length
    end

    def cleanup_older_than(days:)
      cutoff = Time.now - (days * 86_400)
      old_sessions = sessions.select { |s| s[:date] < cutoff }
      old_sessions.each { |s| FileUtils.rm_rf(s[:path]) }
      old_sessions.length
    end

    def format_size(bytes)
      if bytes >= 1_048_576
        format('%.1f MB', bytes / 1_048_576.0)
      elsif bytes >= 1024
        format('%.1f KB', bytes / 1024.0)
      else
        "#{bytes} B"
      end
    end

    private

    def build_session_info(name)
      path = File.join(sessions_dir, name)
      return nil unless File.directory?(path)

      stat = File.stat(path)
      {
        path: path,
        name: name,
        date: stat.mtime,
        size_bytes: directory_size(path)
      }
    end

    def directory_size(dir)
      total = 0
      Dir.glob(File.join(dir, '**', '*'), File::FNM_DOTMATCH).each do |f|
        total += File.size(f) if File.file?(f)
      end
      total
    end
  end
end
