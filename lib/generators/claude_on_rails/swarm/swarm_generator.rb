# frozen_string_literal: true

require 'rails/generators/base'
require 'claude_on_rails'

module ClaudeOnRails
  module Generators
    class SwarmGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      class_option :api_only, type: :boolean, default: false,
                              desc: 'Generate swarm for API-only Rails application'

      class_option :skip_tests, type: :boolean, default: false,
                                desc: 'Skip test agent in swarm configuration'

      class_option :graphql, type: :boolean, default: false,
                             desc: 'Include GraphQL specialist agent'

      class_option :turbo, type: :boolean, default: true,
                           desc: 'Include Turbo/Stimulus specialist agents'

      class_option :mcp_server, type: :boolean, default: true,
                                desc: 'Include Rails MCP Server for enhanced documentation access'

      class_option :dev_mcp, type: :boolean, default: true,
                             desc: 'Include Rails Dev MCP Server for development server management'

      class_option :regenerate, type: :boolean, default: false,
                                desc: 'Re-run detection and update config without overwriting customized prompts'

      class_option :model, type: :string, default: 'opus',
                           desc: 'Default Claude model for agents (opus, sonnet)'

      class_option :cost_optimized, type: :boolean, default: false,
                                    desc: 'Use sonnet for less complex agents to reduce cost'

      def analyze_project
        say 'Analyzing Rails project structure...', :green
        @project_analysis = ClaudeOnRails.analyze_project(Rails.root)

        # Auto-detect features
        @api_only = options[:api_only] || @project_analysis[:api_only]
        @has_graphql = options[:graphql] || @project_analysis[:has_graphql]
        @has_turbo = options[:turbo] && !@api_only
        @has_view_component = @project_analysis[:has_view_component]
        @skip_tests = options[:skip_tests]
        @test_framework = @project_analysis[:test_framework]

        @has_tailwind = @project_analysis[:has_tailwind] && !@api_only

        # Check for i18n usage
        @has_i18n = @project_analysis[:has_i18n]

        # Check for Rails MCP Server
        @include_mcp_server = options[:mcp_server] && ClaudeOnRails::MCPSupport.available?

        # Check for Rails Dev MCP
        @include_dev_mcp = options[:dev_mcp] && check_rails_dev_mcp_availability

        # Check for BooRails security skills
        @has_boorails = ClaudeOnRails::BoorailsSupport.available?

        # Model configuration
        @default_model = options[:model]
        @agent_models = {}

        if options[:cost_optimized]
          sonnet_agents = %w[devops jobs stimulus tailwind database]
          agents.each do |agent|
            @agent_models[agent] = sonnet_agents.include?(agent) ? 'sonnet' : 'opus'
          end
        end

        say "Project type: #{@api_only ? 'API-only' : 'Full-stack Rails'}", :cyan
        say "Test framework: #{@test_framework}", :cyan if @test_framework
        say "GraphQL detected: #{@has_graphql ? 'Yes' : 'No'}", :cyan
        say "Tailwind CSS detected: #{@has_tailwind ? 'Yes' : 'No'}", :cyan
        say "ViewComponent detected: #{@has_view_component ? 'Yes' : 'No'}", :cyan
        say "I18n detected: #{@has_i18n ? 'Yes' : 'No'}", :cyan
        say "Rails MCP Server: #{@include_mcp_server ? 'Available' : 'Not available'}", :cyan
        say "Rails Dev MCP: #{@include_dev_mcp ? 'Available' : 'Not available'}", :cyan
        say "MCP distribution: #{@include_mcp_server ? 'architect, models, controllers, views, tests' : 'N/A'}", :cyan
        say "Database agent: Enabled (#{@project_analysis[:database]})", :cyan
        say "BooRails Security: #{@has_boorails ? 'Available' : 'Not installed'}", :cyan

        # Offer MCP setup if enabled but not available
        offer_mcp_setup if options[:mcp_server] && !@include_mcp_server

        # Suggest BooRails installation if not available
        suggest_boorails_setup unless @has_boorails

        # Show model configuration
        say "Default model: #{@default_model}", :cyan
        say 'Cost-optimized mode: enabled (sonnet for less complex agents)', :cyan if options[:cost_optimized]

        # Show which agents will be created
        say "\nAgents to be created:", :yellow
        agents.each do |agent|
          agent_model = @agent_models[agent] || @default_model
          model_label = agent_model == @default_model ? '' : " (#{agent_model})"
          say "  - #{agent}#{model_label}", :cyan
        end
      end

      def create_swarm_config
        say 'Generating swarm configuration...', :green
        template 'swarm.yml.erb', 'claude-swarm.yml'
      end

      def create_claude_md
        # Always create/update the ClaudeOnRails context file
        template 'claude_on_rails_context.md', '.claude-on-rails/context.md'

        # In regenerate mode, skip CLAUDE.md entirely (user has likely customized it)
        if options[:regenerate]
          if File.exist?('CLAUDE.md')
            say 'Skipping CLAUDE.md (regenerate mode preserves user content)', :yellow
          else
            say 'Creating CLAUDE.md configuration...', :green
            template 'CLAUDE.md.erb', 'CLAUDE.md'
          end
          return
        end

        if File.exist?('CLAUDE.md')
          say 'CLAUDE.md already exists - adding ClaudeOnRails file reference...', :yellow

          existing_content = File.read('CLAUDE.md')

          # Check if file reference already exists
          if existing_content.include?('.claude-on-rails/context.md')
            say '✓ CLAUDE.md already references ClaudeOnRails context', :green
          else
            file_reference = "\n/file:.claude-on-rails/context.md\n"
            append_to_file 'CLAUDE.md', file_reference
            say '✓ Added ClaudeOnRails context reference to existing CLAUDE.md', :green
          end
        else
          say 'Creating CLAUDE.md configuration...', :green
          template 'CLAUDE.md.erb', 'CLAUDE.md'
        end
      end

      def create_agent_prompts
        say 'Setting up agent-specific prompts...', :green

        dest_dir = '.claude-on-rails/prompts'
        empty_directory dest_dir

        Dir[File.join(self.class.source_root, 'prompts', '*')].each do |source_path|
          filename = File.basename(source_path)
          relative_source = File.join('prompts', filename)
          destination_filename = filename.sub(/\.erb\z/, '')
          destination_path = File.join(dest_dir, destination_filename)

          if options[:regenerate] && File.exist?(destination_path)
            # Generate what the template would produce and compare with existing
            fresh_content = if filename.end_with?('.erb')
                              # Render ERB template to get fresh content
                              source = File.join(self.class.source_root, relative_source)
                              context = instance_eval('binding', __FILE__, __LINE__)
                              ERB.new(File.read(source), trim_mode: '-').result(context)
                            else
                              File.read(source_path)
                            end

            existing_content = File.read(destination_path)

            if existing_content != fresh_content
              say "Skipping #{destination_filename} (customized)", :yellow
              next
            end
          end

          if filename.end_with?('.erb')
            template relative_source, destination_path
          else
            copy_file relative_source, destination_path
          end
        end
      end

      def update_gitignore
        say 'Updating .gitignore...', :green
        gitignore_path = Rails.root.join('.gitignore')

        # Create .gitignore if it doesn't exist
        create_file '.gitignore', '' unless File.exist?(gitignore_path)

        gitignore_entries = {
          '.claude-on-rails/sessions/' => '.claude-on-rails/sessions/',
          '.claude-swarm/' => '.claude-swarm/',
          'claude-swarm.log' => 'claude-swarm.log'
        }

        if File.exist?(gitignore_path)
          existing_content = File.read(gitignore_path)
          entries_to_add = gitignore_entries.values.reject { |entry| existing_content.include?(entry) }

          if entries_to_add.empty?
            say 'All .gitignore entries already present', :green
          else
            block = "\n# ClaudeOnRails\n#{entries_to_add.join("\n")}\n"
            append_to_file '.gitignore', block
          end
        else
          append_to_file '.gitignore',
                         "\n# ClaudeOnRails\n.claude-on-rails/sessions/\n.claude-swarm/\nclaude-swarm.log\n"
        end
      end

      def display_next_steps
        if options[:regenerate]
          say "\nSwarm configuration regenerated!", :green
          say 'Customized prompt files were preserved.', :cyan
        else
          say "\nClaudeOnRails swarm configuration created!", :green
        end

        say "\nNext steps:", :yellow
        say '1. Review and customize claude-swarm.yml for your project'
        say '2. Start your Rails development swarm:'
        say '   claude-swarm', :cyan
        say "\nOnce the swarm is running, just describe what you want to build:"
        say '   > Add user authentication with social login', :cyan
        say "\nThe swarm will automatically coordinate the implementation across all layers!"
      end

      private

      def agents
        @agents ||= build_agent_list
      end

      def build_agent_list
        list = ['architect']
        list << 'models' if File.directory?(Rails.root.join('app/models'))
        list << 'database'
        list << 'controllers' if File.directory?(Rails.root.join('app/controllers'))
        list << 'views' if !@api_only && File.directory?(Rails.root.join('app/views'))
        list << 'api' if @api_only && File.directory?(Rails.root.join('app/controllers/api'))
        list << 'graphql' if @has_graphql && File.directory?(Rails.root.join('app/graphql'))
        list << 'stimulus' if @has_turbo && File.directory?(Rails.root.join('app/javascript'))
        list << 'tailwind' if @has_tailwind
        list << 'services' if File.directory?(Rails.root.join('app/services'))
        list << 'jobs' if File.directory?(Rails.root.join('app/jobs'))

        unless @skip_tests
          case @test_framework
          when 'RSpec'
            list << 'tests' if File.directory?(Rails.root.join('spec'))
          when 'Minitest'
            list << 'tests' if File.directory?(Rails.root.join('test'))
          end
        end

        list << 'i18n' if @has_i18n && File.directory?(Rails.root.join('config/locales'))
        list << 'devops' if File.directory?(Rails.root.join('config'))
        list << 'security' if @has_boorails
        list
      end

      def offer_mcp_setup
        say "\n🎯 Rails MCP Server Enhancement Available!", :yellow
        say "Rails MCP Server provides your AI agents with real-time Rails documentation.", :cyan

        if yes?("Would you like to set it up now? (Y/n)", :green)
          say "\nStarting Rails MCP Server setup...", :green
          system('bundle exec rake claude_on_rails:setup_mcp')

          # Re-check availability after setup
          @include_mcp_server = ClaudeOnRails::MCPSupport.available?

          if @include_mcp_server
            say "\n✓ Rails MCP Server is now available!", :green
          else
            say "\nSetup was not completed. Continuing without MCP Server.", :yellow
          end
        else
          say "\nYou can set it up later with: bundle exec rake claude_on_rails:setup_mcp", :cyan
        end
      end

      def suggest_boorails_setup
        say "\nBooRails Security Enhancement Available!", :yellow
        say "BooRails provides deep security auditing for your Rails app (XSS, SQLi, CSRF, and more).", :cyan
        say "Install it with:", :cyan
        say "  bash -lc 'REPO=\"$HOME/.boorails\"; " \
            '[ -d "$REPO/.git" ] || git clone https://github.com/kurenn/boorails.git "$REPO"; ' \
            "\"$REPO\"/install_skills_codex_claude.sh --target claude --force'", :cyan
        say "Then re-run: rails generate claude_on_rails:swarm", :cyan
      end

      def check_rails_dev_mcp_availability
        system('gem list -i rails-dev-mcp > /dev/null 2>&1') ||
          system('which rails-dev-mcp > /dev/null 2>&1')
      rescue StandardError
        false
      end
    end
  end
end
