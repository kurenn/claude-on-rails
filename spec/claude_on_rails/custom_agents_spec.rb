# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClaudeOnRails::CustomAgents do
  let(:tmpdir) { Dir.mktmpdir }
  let(:config_dir) { File.join(tmpdir, '.claude-on-rails') }
  let(:config_file) { File.join(config_dir, 'custom_agents.yml') }

  after { FileUtils.remove_entry(tmpdir) }

  describe '#load' do
    context 'when the config file does not exist' do
      it 'returns an empty hash' do
        agents = described_class.new(tmpdir).load
        expect(agents).to eq({})
      end
    end

    context 'when the config file exists with valid YAML' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          agents:
            payments:
              description: "Payment processing specialist"
              directory: ./app/services/payments
              allowed_tools: [Read, Edit, Write, Bash]
              prompt_file: .claude-on-rails/prompts/payments.md
              connections: [models, services]
            emails:
              description: "Email templates and ActionMailer specialist"
              directory: ./app/mailers
        YAML
      end

      it 'returns agent definitions keyed by symbol' do
        agents = described_class.new(tmpdir).load
        expect(agents).to include(:payments, :emails)
      end

      it 'parses the description correctly' do
        agents = described_class.new(tmpdir).load
        expect(agents[:payments][:description]).to eq('Payment processing specialist')
      end

      it 'parses the directory correctly' do
        agents = described_class.new(tmpdir).load
        expect(agents[:payments][:directory]).to eq('./app/services/payments')
      end

      it 'parses connections correctly' do
        agents = described_class.new(tmpdir).load
        expect(agents[:payments][:connections]).to eq(%w[models services])
      end

      it 'parses allowed_tools correctly' do
        agents = described_class.new(tmpdir).load
        expect(agents[:payments][:allowed_tools]).to eq(%w[Read Edit Write Bash])
      end

      it 'parses prompt_file correctly' do
        agents = described_class.new(tmpdir).load
        expect(agents[:payments][:prompt_file]).to eq('.claude-on-rails/prompts/payments.md')
      end
    end

    context 'when optional fields are missing' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          agents:
            emails:
              description: "Email specialist"
        YAML
      end

      it 'defaults directory to .' do
        agents = described_class.new(tmpdir).load
        expect(agents[:emails][:directory]).to eq('.')
      end

      it 'defaults allowed_tools to the standard set' do
        agents = described_class.new(tmpdir).load
        expect(agents[:emails][:allowed_tools]).to eq(%w[Read Edit Write Bash Grep Glob LS])
      end

      it 'does not include connections when not specified' do
        agents = described_class.new(tmpdir).load
        expect(agents[:emails]).not_to have_key(:connections)
      end

      it 'does not include prompt_file when not specified' do
        agents = described_class.new(tmpdir).load
        expect(agents[:emails]).not_to have_key(:prompt_file)
      end
    end

    context 'when required fields are missing' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          agents:
            broken:
              directory: ./app
        YAML
      end

      it 'raises an error for missing description' do
        expect { described_class.new(tmpdir).load }.to raise_error(
          ClaudeOnRails::Error, /missing required field 'description'/
        )
      end
    end

    context 'when agent config has invalid fields' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          agents:
            bad:
              description: "Bad agent"
              unknown_field: something
        YAML
      end

      it 'raises an error for invalid fields' do
        expect { described_class.new(tmpdir).load }.to raise_error(
          ClaudeOnRails::Error, /invalid fields: unknown_field/
        )
      end
    end

    context 'when agent name conflicts with a built-in agent' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          agents:
            models:
              description: "Override built-in models agent"
        YAML
      end

      it 'raises an error for reserved names' do
        expect { described_class.new(tmpdir).load }.to raise_error(
          ClaudeOnRails::Error, /conflicts with a built-in agent name/
        )
      end
    end

    context 'when YAML has no agents key' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          something_else:
            foo: bar
        YAML
      end

      it 'returns an empty hash' do
        agents = described_class.new(tmpdir).load
        expect(agents).to eq({})
      end
    end

    context 'when initialized with a project analysis hash' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          agents:
            payments:
              description: "Payment specialist"
        YAML
      end

      it 'uses root_path from the analysis hash' do
        agents = described_class.new({ root_path: tmpdir }).load
        expect(agents).to include(:payments)
      end
    end

    context 'when model is specified' do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, <<~YAML)
          agents:
            payments:
              description: "Payment specialist"
              model: sonnet
        YAML
      end

      it 'includes the model in the agent config' do
        agents = described_class.new(tmpdir).load
        expect(agents[:payments][:model]).to eq('sonnet')
      end
    end
  end

  describe '.load_from_file' do
    it 'returns an empty hash when file does not exist' do
      agents = described_class.load_from_file(tmpdir)
      expect(agents).to eq({})
    end

    it 'loads agents from the given root path' do
      FileUtils.mkdir_p(config_dir)
      File.write(config_file, <<~YAML)
        agents:
          emails:
            description: "Email specialist"
      YAML

      agents = described_class.load_from_file(tmpdir)
      expect(agents).to include(:emails)
    end
  end
end
