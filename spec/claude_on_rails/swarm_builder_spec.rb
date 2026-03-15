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
