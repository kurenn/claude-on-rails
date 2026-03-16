# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClaudeOnRails::SwarmBuilder do
  let(:base_analysis) do
    {
      api_only: false,
      test_framework: 'RSpec',
      has_graphql: false,
      has_turbo: true,
      has_devise: false,
      has_sidekiq: false,
      has_boorails: false,
      has_tailwind: false,
      has_view_component: false,
      has_i18n: false,
      javascript_framework: nil,
      database: 'sqlite3',
      deployment: nil,
      custom_patterns: {}
    }
  end

  let(:builder) { described_class.new(analysis) }
  let(:result) { builder.build }
  let(:instances) { result[:swarm][:instances] }

  describe '#build' do
    let(:analysis) { base_analysis }

    it 'returns a valid swarm structure' do
      expect(result[:version]).to eq(1)
      expect(result[:swarm][:name]).to eq('Rails Development Team')
      expect(result[:swarm][:main]).to eq('architect')
    end

    it 'always includes core agents' do
      expect(instances).to include(:architect, :models, :controllers, :services, :jobs, :devops)
    end
  end

  describe 'database agent' do
    context 'with a full-stack app' do
      let(:analysis) { base_analysis }

      it 'always includes the database agent' do
        expect(instances).to include(:database)
      end

      it 'configures read-only tools (no Edit/Write)' do
        database = instances[:database]
        expect(database[:allowed_tools]).to eq(%w[Read Bash Grep Glob LS])
        expect(database[:allowed_tools]).not_to include('Edit', 'Write')
      end

      it 'has no connections (avoids circular dependency with models)' do
        database = instances[:database]
        expect(database[:connections]).to be_nil
      end

      it 'sets directory to project root' do
        database = instances[:database]
        expect(database[:directory]).to eq('.')
      end

      it 'uses the correct prompt file' do
        database = instances[:database]
        expect(database[:prompt_file]).to eq('.claude-on-rails/prompts/database.md')
      end

      it 'adds database to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).to include('database')
      end

      it 'adds database to models agent connections' do
        models = instances[:models]
        expect(models[:connections]).to include('database')
      end
    end

    context 'with an API-only app' do
      let(:analysis) { base_analysis.merge(api_only: true) }

      it 'always includes the database agent' do
        expect(instances).to include(:database)
      end

      it 'adds database to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).to include('database')
      end
    end
  end

  describe 'security agent' do
    context 'when BooRails is available' do
      let(:analysis) { base_analysis.merge(has_boorails: true) }

      it 'includes the security agent' do
        expect(instances).to include(:security)
      end

      it 'configures the security agent correctly' do
        security = instances[:security]
        expect(security[:description]).to include('security')
        expect(security[:directory]).to eq('.')
        expect(security[:allowed_tools]).to include('Bash', 'Read', 'Grep')
        expect(security[:prompt_file]).to eq('.claude-on-rails/prompts/security.md')
      end

      it 'gives security agent connections to models and controllers' do
        security = instances[:security]
        expect(security[:connections]).to include('models', 'controllers')
      end

      it 'adds security to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).to include('security')
      end
    end

    context 'when BooRails is not available' do
      let(:analysis) { base_analysis.merge(has_boorails: false) }

      it 'excludes the security agent' do
        expect(instances).not_to include(:security)
      end

      it 'does not add security to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).not_to include('security')
      end
    end
  end

  describe 'tailwind agent' do
    context 'when Tailwind is available on a full-stack app' do
      let(:analysis) { base_analysis.merge(has_tailwind: true) }

      it 'includes the tailwind agent' do
        expect(instances).to include(:tailwind)
      end

      it 'configures the tailwind agent correctly' do
        tailwind = instances[:tailwind]
        expect(tailwind[:description]).to include('Tailwind CSS')
        expect(tailwind[:directory]).to eq('.')
        expect(tailwind[:allowed_tools]).to include('Bash', 'Read', 'Grep')
        expect(tailwind[:prompt_file]).to eq('.claude-on-rails/prompts/tailwind.md')
      end

      it 'has no connections (avoids circular dependency with views)' do
        tailwind = instances[:tailwind]
        expect(tailwind).not_to have_key(:connections)
      end

      it 'adds tailwind to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).to include('tailwind')
      end

      it 'adds tailwind to views agent connections' do
        views = instances[:views]
        expect(views[:connections]).to include('tailwind')
      end
    end

    context 'when Tailwind is not available' do
      let(:analysis) { base_analysis.merge(has_tailwind: false) }

      it 'excludes the tailwind agent' do
        expect(instances).not_to include(:tailwind)
      end

      it 'does not add tailwind to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).not_to include('tailwind')
      end

      it 'does not add tailwind to views agent connections' do
        views = instances[:views]
        expect(views).not_to have_key(:connections) unless base_analysis[:has_turbo]
      end
    end

    context 'when API-only app has Tailwind' do
      let(:analysis) { base_analysis.merge(has_tailwind: true, api_only: true) }

      it 'excludes the tailwind agent' do
        expect(instances).not_to include(:tailwind)
      end
    end
  end

  describe 'performance agent' do
    context 'with a full-stack app' do
      let(:analysis) { base_analysis }

      it 'is always included' do
        expect(instances).to include(:performance)
      end

      it 'has read-only tools (no Edit or Write)' do
        performance = instances[:performance]
        expect(performance[:allowed_tools]).to eq(%w[Read Bash Grep Glob LS])
        expect(performance[:allowed_tools]).not_to include('Edit', 'Write')
      end

      it 'has connections to models' do
        performance = instances[:performance]
        expect(performance[:connections]).to include('models')
      end

      it 'has connections to views for full-stack apps' do
        performance = instances[:performance]
        expect(performance[:connections]).to include('views')
      end

      it 'is included in architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).to include('performance')
      end

      it 'configures the performance agent correctly' do
        performance = instances[:performance]
        expect(performance[:description]).to include('performance')
        expect(performance[:directory]).to eq('.')
        expect(performance[:prompt_file]).to eq('.claude-on-rails/prompts/performance.md')
      end
    end

    context 'with an API-only app' do
      let(:analysis) { base_analysis.merge(api_only: true) }

      it 'is always included' do
        expect(instances).to include(:performance)
      end

      it 'does not have connections to views' do
        performance = instances[:performance]
        expect(performance[:connections]).not_to include('views')
      end

      it 'has connections to models' do
        performance = instances[:performance]
        expect(performance[:connections]).to include('models')
      end
    end
  end

  describe 'views agent with ViewComponent' do
    context 'when ViewComponent is detected' do
      let(:analysis) { base_analysis.merge(has_view_component: true) }

      it 'includes ViewComponent in the views agent description' do
        views = instances[:views]
        expect(views[:description]).to include('ViewComponent')
      end
    end

    context 'when ViewComponent is not detected' do
      let(:analysis) { base_analysis.merge(has_view_component: false) }

      it 'does not mention ViewComponent in the views agent description' do
        views = instances[:views]
        expect(views[:description]).not_to include('ViewComponent')
      end
    end
  end

  describe 'design_review agent' do
    context 'when full-stack app' do
      let(:analysis) { base_analysis }

      it 'includes the design_review agent' do
        expect(instances).to include(:design_review)
      end

      it 'configures the design_review agent as read-only' do
        design_review = instances[:design_review]
        expect(design_review[:allowed_tools]).to include('Read', 'Bash', 'Grep', 'Glob', 'LS')
        expect(design_review[:allowed_tools]).not_to include('Edit', 'Write')
      end

      it 'configures the design_review agent correctly' do
        design_review = instances[:design_review]
        expect(design_review[:description]).to include('design review')
        expect(design_review[:directory]).to eq('.')
        expect(design_review[:prompt_file]).to eq('.claude-on-rails/prompts/design_review.md')
      end

      it 'has no connections (read-only agent, callers delegate fixes)' do
        design_review = instances[:design_review]
        expect(design_review).not_to have_key(:connections)
      end

      it 'adds design_review to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).to include('design_review')
      end

      it 'adds design_review to views agent connections' do
        views = instances[:views]
        expect(views[:connections]).to include('design_review')
      end
    end

    context 'when API-only app' do
      let(:analysis) { base_analysis.merge(api_only: true) }

      it 'excludes the design_review agent' do
        expect(instances).not_to include(:design_review)
      end

      it 'does not add design_review to architect connections' do
        architect = instances[:architect]
        expect(architect[:connections]).not_to include('design_review')
      end
    end
  end

  describe 'hooks support' do
    context 'when hooks are enabled' do
      let(:analysis) { base_analysis.merge(hooks: true) }

      it 'adds an after hook to the tests agent' do
        tests = instances[:tests]
        expect(tests[:hooks]).to eq(after: 'bundle exec rspec --format progress')
      end

      it 'adds a before hook to the models agent' do
        models = instances[:models]
        expect(models[:hooks]).to eq(before: 'bundle exec rails db:migrate:status')
      end

      context 'with Minitest framework' do
        let(:analysis) { base_analysis.merge(hooks: true, test_framework: 'Minitest') }

        it 'uses rails test command for tests agent after hook' do
          tests = instances[:tests]
          expect(tests[:hooks]).to eq(after: 'bundle exec rails test')
        end
      end
    end

    context 'when hooks are disabled (default)' do
      let(:analysis) { base_analysis }

      it 'does not add hooks to the tests agent' do
        tests = instances[:tests]
        expect(tests).not_to have_key(:hooks)
      end

      it 'does not add hooks to the models agent' do
        models = instances[:models]
        expect(models).not_to have_key(:hooks)
      end
    end
  end

  describe 'conditional agents' do
    context 'with API-only app' do
      let(:analysis) { base_analysis.merge(api_only: true) }

      it 'includes api agent and excludes views' do
        expect(instances).to include(:api)
        expect(instances).not_to include(:views)
      end
    end

    context 'with GraphQL' do
      let(:analysis) { base_analysis.merge(has_graphql: true) }

      it 'includes graphql agent' do
        expect(instances).to include(:graphql)
      end
    end

    context 'without test framework' do
      let(:analysis) { base_analysis.merge(test_framework: nil) }

      it 'excludes tests agent' do
        expect(instances).not_to include(:tests)
      end
    end
  end
end
