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
end
