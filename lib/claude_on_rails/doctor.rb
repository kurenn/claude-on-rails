# frozen_string_literal: true

require 'yaml'

module ClaudeOnRails
  class Doctor
    CheckResult = Struct.new(:name, :status, :message, keyword_init: true)

    attr_reader :root_path

    def initialize(root_path = Dir.pwd)
      @root_path = root_path.to_s
    end

    def run
      [
        check_ruby_version,
        check_rails_version,
        check_claude_swarm_installed,
        check_swarm_config_exists,
        check_swarm_config_valid,
        check_prompt_files,
        check_mcp_server,
        check_mcp_placement,
        check_claude_swarm_version
      ]
    end

    def healthy?
      run.none? { |result| result.status == :error }
    end

    private

    def check_ruby_version
      version = RUBY_VERSION
      if Gem::Version.new(version) >= Gem::Version.new('3.3.0')
        CheckResult.new(name: 'Ruby version', status: :ok, message: version)
      else
        CheckResult.new(name: 'Ruby version', status: :error, message: "#{version} (requires >= 3.3.0)")
      end
    end

    def check_rails_version
      version = detect_rails_version
      if version.nil?
        CheckResult.new(name: 'Rails version', status: :error, message: 'not detected')
      elsif Gem::Version.new(version) >= Gem::Version.new('6.0')
        CheckResult.new(name: 'Rails version', status: :ok, message: version)
      else
        CheckResult.new(name: 'Rails version', status: :error, message: "#{version} (requires >= 6.0)")
      end
    end

    def check_claude_swarm_installed
      if claude_swarm_available?
        CheckResult.new(name: 'claude-swarm installed', status: :ok, message: claude_swarm_version || 'yes')
      else
        CheckResult.new(name: 'claude-swarm installed', status: :error, message: 'not found in PATH')
      end
    end

    def check_claude_swarm_version
      version = claude_swarm_version
      return CheckResult.new(name: 'claude-swarm version', status: :error, message: 'not installed') unless version

      if Gem::Version.new(version) >= Gem::Version.new('1.0')
        CheckResult.new(name: 'claude-swarm version', status: :ok, message: version)
      else
        CheckResult.new(name: 'claude-swarm version', status: :warning,
                        message: "#{version} (recommend >= 1.0)")
      end
    end

    def check_swarm_config_exists
      config_path = File.join(root_path, 'claude-swarm.yml')
      if File.exist?(config_path)
        CheckResult.new(name: 'Swarm config exists', status: :ok, message: 'claude-swarm.yml found')
      else
        CheckResult.new(name: 'Swarm config exists', status: :error, message: 'claude-swarm.yml not found')
      end
    end

    def check_swarm_config_valid
      config_path = File.join(root_path, 'claude-swarm.yml')
      unless File.exist?(config_path)
        return CheckResult.new(name: 'Swarm config valid', status: :error,
                               message: 'config file missing')
      end

      config = YAML.safe_load_file(config_path, permitted_classes: [Symbol])
      swarm = config&.dig('swarm')

      errors = []
      errors << 'missing swarm key' unless swarm
      errors << 'missing swarm.main' unless swarm&.dig('main')
      errors << 'missing swarm.instances' unless swarm&.dig('instances')

      if errors.empty?
        CheckResult.new(name: 'Swarm config valid', status: :ok, message: 'valid structure')
      else
        CheckResult.new(name: 'Swarm config valid', status: :error, message: errors.join(', '))
      end
    rescue Psych::SyntaxError => e
      CheckResult.new(name: 'Swarm config valid', status: :error, message: "invalid YAML: #{e.message}")
    end

    def check_prompt_files
      config_path = File.join(root_path, 'claude-swarm.yml')
      unless File.exist?(config_path)
        return CheckResult.new(name: 'Prompt files', status: :error,
                               message: 'config file missing')
      end

      config = YAML.safe_load_file(config_path, permitted_classes: [Symbol])
      instances = config&.dig('swarm', 'instances') || {}

      prompt_files = instances.values.filter_map { |inst| inst['prompt_file'] || inst[:prompt_file] }

      if prompt_files.empty?
        return CheckResult.new(name: 'Prompt files', status: :ok,
                               message: 'no prompt files configured')
      end

      found = prompt_files.count { |pf| File.exist?(File.join(root_path, pf)) }
      total = prompt_files.size

      if found == total
        CheckResult.new(name: 'Prompt files', status: :ok, message: "#{found}/#{total} found")
      else
        missing = prompt_files.reject { |pf| File.exist?(File.join(root_path, pf)) }
        CheckResult.new(name: 'Prompt files', status: :error,
                        message: "#{found}/#{total} found (missing: #{missing.join(', ')})")
      end
    rescue Psych::SyntaxError
      CheckResult.new(name: 'Prompt files', status: :error, message: 'cannot parse config')
    end

    def check_mcp_server
      if mcp_server_installed?
        CheckResult.new(name: 'MCP Server', status: :ok, message: 'rails-mcp-server installed')
      else
        CheckResult.new(name: 'MCP Server', status: :warning, message: 'not installed (optional)')
      end
    end

    def check_mcp_placement
      config_path = File.join(root_path, 'claude-swarm.yml')
      unless File.exist?(config_path)
        return CheckResult.new(name: 'MCP placement', status: :error,
                               message: 'config file missing')
      end

      config = YAML.safe_load_file(config_path, permitted_classes: [Symbol])
      swarm = config&.dig('swarm') || {}

      if swarm.key?('mcps') || swarm.key?(:mcps)
        CheckResult.new(name: 'MCP placement', status: :error,
                        message: 'mcps found at swarm level (should be instance level)')
      else
        CheckResult.new(name: 'MCP placement', status: :ok, message: 'correctly placed')
      end
    rescue Psych::SyntaxError
      CheckResult.new(name: 'MCP placement', status: :error, message: 'cannot parse config')
    end

    def detect_rails_version
      if defined?(Rails) && Rails.respond_to?(:version)
        Rails.version
      else
        detect_rails_version_from_gemfile
      end
    end

    def detect_rails_version_from_gemfile
      lockfile = File.join(root_path, 'Gemfile.lock')
      return nil unless File.exist?(lockfile)

      content = File.read(lockfile)
      match = content.match(/^\s+rails\s+\((\d+\.\d+(?:\.\d+)?)\)/)
      match ? match[1] : nil
    end

    def claude_swarm_available?
      system('which claude-swarm > /dev/null 2>&1')
    rescue StandardError
      false
    end

    def claude_swarm_version
      Gem.loaded_specs['claude_swarm']&.version&.to_s
    rescue StandardError
      nil
    end

    def mcp_server_installed?
      system('gem list -i rails-mcp-server > /dev/null 2>&1')
    rescue StandardError
      false
    end
  end
end
