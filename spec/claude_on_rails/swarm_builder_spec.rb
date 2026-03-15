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

      it 'gives tailwind agent a connection to views' do
        tailwind = instances[:tailwind]
        expect(tailwind[:connections]).to include('views')
      end

      it 'gives tailwind agent a connection to stimulus when Turbo is present' do
        tailwind = instances[:tailwind]
        expect(tailwind[:connections]).to include('stimulus')
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

    context 'when Tailwind is available without Turbo' do
      let(:analysis) { base_analysis.merge(has_tailwind: true, has_turbo: false) }

      it 'does not give tailwind agent a connection to stimulus' do
        tailwind = instances[:tailwind]
        expect(tailwind[:connections]).not_to include('stimulus')
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
