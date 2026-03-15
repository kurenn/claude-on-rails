# frozen_string_literal: true

namespace :claude_on_rails do
  desc 'Setup Rails MCP Server for enhanced documentation access'
  task setup_mcp: :environment do
    require 'claude_on_rails/mcp_installer'
    ClaudeOnRails::MCPInstaller.new.run
  end

  desc 'Check Rails MCP Server status and available resources'
  task mcp_status: :environment do
    if ClaudeOnRails::MCPSupport.available?
      puts '✓ Rails MCP Server is installed'

      downloaded = ClaudeOnRails::MCPSupport.downloaded_resources
      missing = ClaudeOnRails::MCPSupport.missing_resources

      if downloaded.any?
        puts "\nDownloaded resources:"
        downloaded.each { |resource| puts "  ✓ #{resource}" }
      end

      if missing.any?
        puts "\nMissing resources:"
        missing.each { |resource| puts "  ✗ #{resource}" }
        puts "\nRun 'bundle exec rake claude_on_rails:setup_mcp' to download missing resources."
      else
        puts "\n✓ All resources are downloaded"
      end
    else
      puts '✗ Rails MCP Server is not installed'
      puts "\nRun 'bundle exec rake claude_on_rails:setup_mcp' to install and configure it."
    end
  end

  desc 'Show comprehensive overview of ClaudeOnRails swarm configuration and project status'
  task status: :environment do
    require 'claude_on_rails/status_display'
    ClaudeOnRails::StatusDisplay.new(Rails.root).run
  end

  desc 'List configured swarm agents'
  task agents: :environment do
    require 'claude_on_rails/status_display'
    ClaudeOnRails::StatusDisplay.new(Rails.root).show_agents
  end

  desc 'Detect and fix known issues in claude-swarm.yml from older versions'
  task upgrade: :environment do
    require 'claude_on_rails/upgrader'

    puts "ClaudeOnRails Upgrade"
    puts "====================="
    puts "Checking claude-swarm.yml..."
    puts

    upgrader = ClaudeOnRails::Upgrader.new(Rails.root)
    report = upgrader.run

    fixes = report[:fixes]
    issues = report[:issues]
    total = fixes.size + issues.size

    if total.zero?
      puts "No issues found. Your configuration is up to date!"
    else
      puts "Found #{total} issue#{'s' if total != 1}:"
      fixes.each { |fix| puts "  \u2713 Fixed: #{fix}" }
      issues.each do |issue|
        prefix = case issue[:type]
                 when :warning then "\u26A0 Warning"
                 when :suggestion then "\u26A0 Info"
                 else "\u2717 Error"
                 end
        puts "  #{prefix}: #{issue[:message]}"
      end
    end

    if report[:config_modified]
      upgrader.apply!
      puts
      puts "Backup saved to: claude-swarm.yml.backup"
      puts "Updated: claude-swarm.yml"
    end
  end

  desc 'Run diagnostic checks on ClaudeOnRails setup'
  task doctor: :environment do
    require 'claude_on_rails/doctor'

    puts 'ClaudeOnRails Doctor'
    puts '===================='

    doctor = ClaudeOnRails::Doctor.new(Rails.root)
    results = doctor.run

    passed = 0
    warnings = 0
    errors = 0

    results.each do |result|
      case result.status
      when :ok
        puts "\e[32m\u2713 #{result.name}: #{result.message}\e[0m"
        passed += 1
      when :warning
        puts "\e[33m\u26a0 #{result.name}: #{result.message}\e[0m"
        warnings += 1
      when :error
        puts "\e[31m\u2717 #{result.name}: #{result.message}\e[0m"
        errors += 1
      end
    end

    total = results.size
    warning_label = warnings == 1 ? 'warning' : 'warnings'
    error_label = errors == 1 ? 'error' : 'errors'
    puts "\n#{total} checks, #{passed} passed, #{warnings} #{warning_label}, #{errors} #{error_label}"

    exit 1 if errors.positive?
  end

  desc 'List all swarm sessions with date and size'
  task sessions: :environment do
    require 'claude_on_rails/session_manager'
    manager = ClaudeOnRails::SessionManager.new(Rails.root)
    all_sessions = manager.sessions

    puts 'ClaudeOnRails Sessions'
    puts '======================'

    if all_sessions.empty?
      puts '  No sessions found.'
    else
      all_sessions.each_with_index do |session, index|
        date_str = session[:date].strftime('%Y-%m-%d %H:%M')
        size_str = manager.format_size(session[:size_bytes])
        puts format('  %<num>d. %<date>s  %<name>s  (%<size>s)', num: index + 1, date: date_str, name: session[:name],
                                                                 size: size_str)
      end
    end

    puts
    puts "Total: #{all_sessions.length} sessions, #{manager.format_size(manager.total_size)}"
  end

  namespace :sessions do
    desc 'Remove old sessions (set KEEP=N, default 5; or DAYS=N to remove by age)'
    task cleanup: :environment do
      require 'claude_on_rails/session_manager'
      manager = ClaudeOnRails::SessionManager.new(Rails.root)

      removed = if ENV['DAYS']
                  manager.cleanup_older_than(days: ENV['DAYS'].to_i)
                else
                  keep = (ENV['KEEP'] || 5).to_i
                  manager.cleanup(keep: keep)
                end

      puts "Removed #{removed} session(s)."
    end

    desc 'Show total disk usage of swarm sessions'
    task size: :environment do
      require 'claude_on_rails/session_manager'
      manager = ClaudeOnRails::SessionManager.new(Rails.root)

      puts "Total session disk usage: #{manager.format_size(manager.total_size)}"
      puts "Sessions: #{manager.sessions.length}"
    end
  end
end
