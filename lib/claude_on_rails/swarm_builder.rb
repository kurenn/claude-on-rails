# frozen_string_literal: true

module ClaudeOnRails
  class SwarmBuilder
    attr_reader :project_analysis

    def initialize(project_analysis)
      @project_analysis = project_analysis
    end

    def build
      {
        version: 1,
        swarm: {
          name: 'Rails Development Team',
          main: 'architect',
          instances: build_instances
        }
      }
    end

    private

    def model_for(agent_name)
      ClaudeOnRails.configuration.model_for(agent_name)
    end

    def build_instances
      instances = {}

      # Always include architect
      instances[:architect] = build_architect

      # Core agents
      instances[:models] = build_models_agent
      instances[:controllers] = build_controllers_agent

      # Conditional agents
      instances[:views] = build_views_agent unless project_analysis[:api_only]

      instances[:api] = build_api_agent if project_analysis[:api_only]

      instances[:graphql] = build_graphql_agent if project_analysis[:has_graphql]

      instances[:stimulus] = build_stimulus_agent if project_analysis[:has_turbo] && !project_analysis[:api_only]

      instances[:tailwind] = build_tailwind_agent if project_analysis[:has_tailwind] && !project_analysis[:api_only]

      # Supporting agents
      instances[:services] = build_services_agent
      instances[:jobs] = build_jobs_agent

      instances[:tests] = build_tests_agent if project_analysis[:test_framework]

      instances[:devops] = build_devops_agent

      instances[:security] = build_security_agent if project_analysis[:has_boorails]

      instances
    end

    def build_architect
      connections = %w[models controllers]
      connections << 'views' unless project_analysis[:api_only]
      connections << 'api' if project_analysis[:api_only]
      connections << 'graphql' if project_analysis[:has_graphql]
      connections << 'tailwind' if project_analysis[:has_tailwind] && !project_analysis[:api_only]
      connections << 'services'
      connections << 'jobs'
      connections << 'tests' if project_analysis[:test_framework]
      connections << 'devops'
      connections << 'security' if project_analysis[:has_boorails]

      {
        description: "Rails architect coordinating #{project_analysis[:api_only] ? 'API' : 'full-stack'} development",
        directory: '.',
        model: model_for('architect'),
        connections: connections,
        prompt_file: '.claude-on-rails/prompts/architect.md',
        vibe: ClaudeOnRails.configuration.vibe_mode
      }
    end

    def build_models_agent
      {
        description: 'ActiveRecord models, migrations, and database optimization specialist',
        directory: './app/models',
        model: model_for('models'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/models.md'
      }
    end

    def build_controllers_agent
      connections = ['services']
      connections << 'api' if project_analysis[:api_only]

      {
        description: 'Rails controllers, routing, and request handling specialist',
        directory: './app/controllers',
        model: model_for('controllers'),
        connections: connections.empty? ? nil : connections,
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/controllers.md'
      }.compact
    end

    def build_views_agent
      connections = []
      connections << 'stimulus' if project_analysis[:has_turbo]
      connections << 'tailwind' if project_analysis[:has_tailwind]

      description = if project_analysis[:has_view_component]
                      'Rails views, layouts, partials, ViewComponent, and asset pipeline specialist'
                    else
                      'Rails views, layouts, partials, and asset pipeline specialist'
                    end

      {
        description: description,
        directory: './app/views',
        model: model_for('views'),
        connections: connections.empty? ? nil : connections,
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/views.md'
      }.compact
    end

    def build_api_agent
      {
        description: 'RESTful API design, serialization, and versioning specialist',
        directory: './app/controllers/api',
        model: model_for('api'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/api.md'
      }
    end

    def build_graphql_agent
      {
        description: 'GraphQL schema, resolvers, and mutations specialist',
        directory: './app/graphql',
        model: model_for('graphql'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/graphql.md'
      }
    end

    def build_stimulus_agent
      {
        description: 'Stimulus.js controllers and Turbo integration specialist',
        directory: './app/javascript',
        model: model_for('stimulus'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/stimulus.md'
      }
    end

    def build_tailwind_agent
      connections = ['views']
      connections << 'stimulus' if project_analysis[:has_turbo]

      {
        description: 'Tailwind CSS styling, responsive design, and Rails frontend integration specialist',
        directory: '.',
        model: model_for('tailwind'),
        connections: connections,
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/tailwind.md'
      }
    end

    def build_services_agent
      {
        description: 'Service objects, business logic, and design patterns specialist',
        directory: './app/services',
        model: model_for('services'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/services.md'
      }
    end

    def build_jobs_agent
      {
        description: 'Background jobs, ActiveJob, and async processing specialist',
        directory: './app/jobs',
        model: model_for('jobs'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/jobs.md'
      }
    end

    def build_tests_agent
      test_dir = project_analysis[:test_framework] == 'RSpec' ? './spec' : './test'

      {
        description: "#{project_analysis[:test_framework]} testing, factories, and test coverage specialist",
        directory: test_dir,
        model: model_for('tests'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/tests.md'
      }
    end

    def build_devops_agent
      {
        description: 'Deployment, Docker, CI/CD, and production configuration specialist',
        directory: './config',
        model: model_for('devops'),
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/devops.md'
      }
    end

    def build_security_agent
      connections = %w[models controllers]
      connections << 'views' unless project_analysis[:api_only]
      connections << 'api' if project_analysis[:api_only]

      {
        description: 'Application security auditing specialist powered by BooRails',
        directory: '.',
        model: model_for('security'),
        connections: connections,
        allowed_tools: %w[Read Edit Write Bash Grep Glob LS],
        prompt_file: '.claude-on-rails/prompts/security.md'
      }
    end
  end
end
