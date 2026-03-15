# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module ClaudeOnRails
  class Upgrader
    CONFIG_FILE = 'claude-swarm.yml'
    BACKUP_FILE = "#{CONFIG_FILE}.backup".freeze

    attr_reader :root_path, :issues

    def initialize(root_path)
      @root_path = root_path.to_s
      @issues = []
      @fixes = []
      @config = nil
      @config_modified = false
    end

    def run
      @issues = []
      @fixes = []

      unless File.exist?(config_path)
        @issues << { type: :error, message: "No claude-swarm.yml found in #{root_path}" }
        return build_report
      end

      return build_report unless load_config

      check_mcp_placement
      check_claude_swarm_version
      check_missing_design_review_agent
      check_missing_prompt_files

      build_report
    end

    def apply!
      return unless @config_modified

      create_backup
      write_config
    end

    private

    def config_path
      File.join(root_path, CONFIG_FILE)
    end

    def backup_path
      File.join(root_path, BACKUP_FILE)
    end

    def load_config
      @original_content = File.read(config_path)
      @config = YAML.safe_load(@original_content, permitted_classes: [Symbol])

      unless @config.is_a?(Hash)
        @issues << { type: :error, message: "claude-swarm.yml has invalid structure" }
        return false
      end

      true
    rescue Psych::SyntaxError
      @issues << { type: :error, message: "claude-swarm.yml has invalid YAML syntax" }
      false
    end

    def check_mcp_placement
      swarm = @config['swarm']
      return unless swarm.is_a?(Hash)

      swarm_mcps = swarm['mcps']
      return unless swarm_mcps

      main_agent = swarm['main'] || 'architect'
      instances = swarm['instances']
      return unless instances.is_a?(Hash)

      architect = instances[main_agent]
      return unless architect.is_a?(Hash)

      existing_mcps = architect['mcps'] || []
      merged_mcps = existing_mcps + swarm_mcps

      architect['mcps'] = merged_mcps
      swarm.delete('mcps')

      @config_modified = true
      @fixes << "MCP servers moved from swarm level to #{main_agent} instance"
    end

    def check_claude_swarm_version
      version = claude_swarm_gem_version
      return unless version

      return unless Gem::Version.new(version) < Gem::Version.new('1.0')

      @issues << { type: :warning, message: "claude_swarm gem version #{version} is below 1.0 - consider upgrading" }
    end

    def check_missing_design_review_agent
      return unless full_stack_app?

      swarm = @config['swarm']
      return unless swarm.is_a?(Hash)

      instances = swarm['instances']
      return unless instances.is_a?(Hash)

      return if instances.key?('design_review')

      @issues << {
        type: :suggestion,
        message: "Consider adding design_review agent (run: rails generate claude_on_rails:swarm --regenerate)"
      }
    end

    def check_missing_prompt_files
      swarm = @config['swarm']
      return unless swarm.is_a?(Hash)

      instances = swarm['instances']
      return unless instances.is_a?(Hash)

      missing = []
      instances.each_value do |instance|
        next unless instance.is_a?(Hash)

        prompt_file = instance['prompt_file']
        next unless prompt_file

        full_path = File.join(root_path, prompt_file)
        missing << prompt_file unless File.exist?(full_path)
      end

      return if missing.empty?

      @issues << {
        type: :warning,
        message: "Missing prompt files: #{missing.join(', ')}"
      }
    end

    def full_stack_app?
      app_config = File.join(root_path, 'config', 'application.rb')
      return true unless File.exist?(app_config)

      !File.read(app_config).include?('config.api_only = true')
    end

    def claude_swarm_gem_version
      Gem.loaded_specs['claude_swarm']&.version&.to_s
    rescue StandardError
      nil
    end

    def create_backup
      FileUtils.cp(config_path, backup_path)
    end

    def write_config
      File.write(config_path, YAML.dump(@config))
    end

    def build_report
      {
        fixes: @fixes.dup,
        issues: @issues.dup,
        config_modified: @config_modified
      }
    end
  end
end
