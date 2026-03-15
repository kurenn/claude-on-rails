# frozen_string_literal: true

require 'yaml'

module ClaudeOnRails
  class StatusDisplay
    PROMPT_FILES = %w[
      architect.md models.md controllers.md views.md api.md
      graphql.md stimulus.md services.md jobs.md tests.md devops.md
    ].freeze

    CUSTOM_PATTERN_DIRS = {
      'Service objects' => 'app/services',
      'Form objects' => 'app/forms',
      'Presenters' => 'app/presenters',
      'Query objects' => 'app/queries',
      'Policies' => 'app/policies',
      'Serializers' => 'app/serializers'
    }.freeze

    FEATURE_GEMS = {
      'GraphQL' => 'graphql',
      'Turbo/Stimulus' => 'turbo-rails',
      'Devise' => 'devise',
      'Sidekiq' => 'sidekiq',
      'Tailwind' => 'tailwindcss-rails',
      'ViewComponent' => 'view_component',
      'I18n' => nil
    }.freeze

    attr_reader :root_path

    def initialize(root_path)
      @root_path = root_path.to_s
    end

    def run
      analysis = ClaudeOnRails.analyze_project(root_path)

      print_header
      print_project_analysis(analysis)
      print_detected_features(analysis)
      print_external_tools
      print_custom_patterns
      print_swarm_configuration
      print_recommendations(analysis)
    end

    def show_agents
      swarm_config = load_swarm_config
      if swarm_config
        agents = extract_agents(swarm_config)
        puts "Configured agents: #{agents.join(', ')}"
      else
        puts "No claude-swarm.yml found. Run 'rails generate claude_on_rails:swarm' to create one."
      end
    end

    private

    def print_header
      puts "ClaudeOnRails Status"
      puts "=" * 20
    end

    def print_project_analysis(analysis)
      project_type = analysis[:api_only] ? 'API-only' : 'Full-stack Rails'

      puts "\nProject Analysis:"
      puts "  Project type:     #{project_type}"
      puts "  Database:         #{analysis[:database]}"
      puts "  Test framework:   #{analysis[:test_framework] || 'None detected'}"
      puts "  Deployment:       #{analysis[:deployment]}"
      puts "  Ruby version:     #{ruby_version}"
      puts "  Rails version:    #{rails_version}"
    end

    def print_detected_features(analysis)
      puts "\nDetected Features:"
      puts "  GraphQL:          #{yes_no(analysis[:has_graphql])}"
      puts "  Turbo/Stimulus:   #{yes_no(analysis[:has_turbo])}"
      puts "  Devise:           #{yes_no(analysis[:has_devise])}"
      puts "  Sidekiq:          #{yes_no(analysis[:has_sidekiq])}"
      puts "  Tailwind:         #{yes_no(gem_in_gemfile?('tailwindcss-rails'))}"
      puts "  ViewComponent:    #{yes_no(gem_in_gemfile?('view_component'))}"
      puts "  I18n:             #{yes_no(i18n_configured?)}"
    end

    def print_external_tools
      puts "\nExternal Tools:"
      puts "  Rails MCP Server: #{mcp_server_status}"
      puts "  Rails Dev MCP:    #{dev_mcp_status}"
      puts "  BooRails:         #{boorails_status}"
    end

    def print_custom_patterns
      puts "\nCustom Patterns:"
      CUSTOM_PATTERN_DIRS.each do |label, dir|
        present = File.directory?(File.join(root_path, dir))
        detail = present ? "Yes (#{dir})" : "No"
        puts "  #{label.ljust(15)} #{detail}"
      end
    end

    def print_swarm_configuration
      puts "\nSwarm Configuration:"
      swarm_config = load_swarm_config

      if swarm_config
        puts "  Config file:      claude-swarm.yml (exists)"
        agents = extract_agents(swarm_config)
        puts "  Agents configured: #{agents.join(', ')}"
        print_prompt_files_status
      else
        puts "  Config file:      claude-swarm.yml (missing)"
        puts "  Agents configured: none"
        puts "  Prompt files:     N/A"
      end
    end

    def print_prompt_files_status
      prompts_dir = File.join(root_path, '.claude-on-rails', 'prompts')
      if File.directory?(prompts_dir)
        existing = PROMPT_FILES.count { |f| File.exist?(File.join(prompts_dir, f)) }
        puts "  Prompt files:     #{existing}/#{PROMPT_FILES.size} present"
      else
        puts "  Prompt files:     0/#{PROMPT_FILES.size} present"
      end
    end

    def print_recommendations(analysis)
      recommendations = build_recommendations(analysis)
      return if recommendations.empty?

      puts "\nRecommendations:"
      recommendations.each { |rec| puts "  - #{rec}" }
    end

    def build_recommendations(analysis)
      recs = []

      recs << "Install Rails MCP Server for enhanced documentation access" unless ClaudeOnRails::MCPSupport.available?

      recs << "Install BooRails for security auditing" unless boorails_available?

      swarm_config = load_swarm_config
      unless swarm_config
        recs << "Run 'rails generate claude_on_rails:swarm' to create swarm configuration"
        return recs
      end

      agents = extract_agents(swarm_config)

      if analysis[:has_graphql] && !agents.include?('graphql')
        recs << "Consider adding GraphQL agent (graphql gem detected but agent not configured)"
      end

      if analysis[:has_turbo] && !analysis[:api_only] && !agents.include?('stimulus')
        recs << "Consider adding Stimulus agent (Turbo/Stimulus detected but agent not configured)"
      end

      prompts_dir = File.join(root_path, '.claude-on-rails', 'prompts')
      if File.directory?(prompts_dir)
        missing = PROMPT_FILES.reject { |f| File.exist?(File.join(prompts_dir, f)) }
        recs << "Missing prompt files: #{missing.join(', ')} - re-run generator to create them" if missing.any?
      else
        recs << "No prompt files found - run 'rails generate claude_on_rails:swarm' to create them"
      end

      recs
    end

    def load_swarm_config
      config_path = File.join(root_path, 'claude-swarm.yml')
      return nil unless File.exist?(config_path)

      YAML.safe_load_file(config_path, permitted_classes: [Symbol])
    rescue Psych::SyntaxError
      nil
    end

    def extract_agents(config)
      instances = config.dig('swarm', 'instances') || config.dig(:swarm, :instances) || {}
      instances.keys.map(&:to_s)
    end

    def yes_no(value)
      value ? "Yes" : "No"
    end

    def ruby_version
      RUBY_VERSION
    end

    def rails_version
      if defined?(Rails) && Rails.respond_to?(:version)
        Rails.version
      else
        "unknown"
      end
    end

    def gem_in_gemfile?(gem_name)
      gemfile_path = File.join(root_path, 'Gemfile')
      return false unless File.exist?(gemfile_path)

      File.read(gemfile_path).include?(gem_name)
    end

    def i18n_configured?
      locale_dir = File.join(root_path, 'config', 'locales')
      return false unless File.directory?(locale_dir)

      # More than just the default en.yml suggests active i18n usage
      locale_files = Dir[File.join(locale_dir, '*.yml')] + Dir[File.join(locale_dir, '*.rb')]
      locale_files.size > 1
    end

    def mcp_server_status
      ClaudeOnRails::MCPSupport.available? ? "Available" : "Not installed"
    end

    def dev_mcp_status
      dev_mcp_available? ? "Available" : "Not installed"
    end

    def boorails_status
      if boorails_available?
        tools = detect_boorails_tools
        if tools.any?
          "Available (#{tools.join(', ')})"
        else
          "Available"
        end
      else
        "Not installed"
      end
    end

    def dev_mcp_available?
      system('gem list -i rails-dev-mcp > /dev/null 2>&1') ||
        system('which rails-dev-mcp > /dev/null 2>&1')
    rescue StandardError
      false
    end

    def boorails_available?
      system('gem list -i boorails > /dev/null 2>&1') ||
        system('which boorails > /dev/null 2>&1')
    rescue StandardError
      false
    end

    def detect_boorails_tools
      tools = []
      tools << 'rails-security' if system('which rails-security > /dev/null 2>&1')
      tools << 'rails-diagnose' if system('which rails-diagnose > /dev/null 2>&1')
      tools
    rescue StandardError
      []
    end
  end
end
