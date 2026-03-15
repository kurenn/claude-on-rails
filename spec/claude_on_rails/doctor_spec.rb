# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'claude_on_rails/doctor'

RSpec.describe ClaudeOnRails::Doctor do
  let(:tmpdir) { Dir.mktmpdir }
  let(:doctor) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  before do
    # Stub external system calls by default
    allow(doctor).to receive(:claude_swarm_available?).and_return(true)
    allow(doctor).to receive(:claude_swarm_version).and_return('1.0.11')
    allow(doctor).to receive(:mcp_server_installed?).and_return(true)

    # Create a valid swarm config
    write_valid_swarm_config
    write_gemfile_lock
  end

  describe '#run' do
    it 'returns an array of CheckResult objects' do
      results = doctor.run
      expect(results).to all(be_a(ClaudeOnRails::Doctor::CheckResult))
    end

    it 'returns ok for a valid setup' do
      results = doctor.run
      statuses = results.map(&:status)
      expect(statuses).to all(eq(:ok))
    end
  end

  describe '#healthy?' do
    it 'returns true when no errors' do
      expect(doctor).to be_healthy
    end

    it 'returns false when errors exist' do
      # Remove the swarm config to trigger an error
      FileUtils.rm_f(File.join(tmpdir, 'claude-swarm.yml'))
      expect(doctor).not_to be_healthy
    end

    it 'returns true when only warnings exist' do
      allow(doctor).to receive(:mcp_server_installed?).and_return(false)
      expect(doctor).to be_healthy
    end
  end

  describe 'swarm config checks' do
    it 'returns error when swarm config is missing' do
      FileUtils.rm_f(File.join(tmpdir, 'claude-swarm.yml'))

      results = doctor.run
      config_check = results.find { |r| r.name == 'Swarm config exists' }

      expect(config_check.status).to eq(:error)
      expect(config_check.message).to include('not found')
    end

    it 'returns error when swarm config has invalid YAML' do
      File.write(File.join(tmpdir, 'claude-swarm.yml'), "invalid: yaml: {\n  broken")

      results = doctor.run
      valid_check = results.find { |r| r.name == 'Swarm config valid' }

      expect(valid_check.status).to eq(:error)
      expect(valid_check.message).to include('invalid YAML')
    end

    it 'returns error when swarm config missing required keys' do
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump('swarm' => { 'name' => 'test' }))

      results = doctor.run
      valid_check = results.find { |r| r.name == 'Swarm config valid' }

      expect(valid_check.status).to eq(:error)
      expect(valid_check.message).to include('missing swarm.main')
    end

    it 'returns ok when swarm config is valid' do
      results = doctor.run
      valid_check = results.find { |r| r.name == 'Swarm config valid' }

      expect(valid_check.status).to eq(:ok)
      expect(valid_check.message).to eq('valid structure')
    end
  end

  describe 'MCP checks' do
    it 'returns warning when MCP not installed' do
      allow(doctor).to receive(:mcp_server_installed?).and_return(false)

      results = doctor.run
      mcp_check = results.find { |r| r.name == 'MCP Server' }

      expect(mcp_check.status).to eq(:warning)
      expect(mcp_check.message).to include('not installed')
    end

    it 'returns ok when MCP is installed' do
      results = doctor.run
      mcp_check = results.find { |r| r.name == 'MCP Server' }

      expect(mcp_check.status).to eq(:ok)
    end

    it 'returns error when MCP at swarm level' do
      swarm_config = {
        'swarm' => {
          'main' => 'architect',
          'mcps' => { 'rails-mcp' => { 'command' => 'rails-mcp-server' } },
          'instances' => {
            'architect' => { 'description' => 'Main architect' }
          }
        }
      }
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_config))

      results = doctor.run
      placement_check = results.find { |r| r.name == 'MCP placement' }

      expect(placement_check.status).to eq(:error)
      expect(placement_check.message).to include('swarm level')
    end

    it 'returns ok when MCP at instance level' do
      results = doctor.run
      placement_check = results.find { |r| r.name == 'MCP placement' }

      expect(placement_check.status).to eq(:ok)
    end
  end

  describe 'prompt file checks' do
    it 'returns error when prompt files are missing' do
      swarm_config = {
        'swarm' => {
          'main' => 'architect',
          'instances' => {
            'architect' => {
              'description' => 'Main architect',
              'prompt_file' => '.claude-on-rails/prompts/architect.md'
            },
            'models' => {
              'description' => 'Models agent',
              'prompt_file' => '.claude-on-rails/prompts/models.md'
            }
          }
        }
      }
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_config))

      results = doctor.run
      prompt_check = results.find { |r| r.name == 'Prompt files' }

      expect(prompt_check.status).to eq(:error)
      expect(prompt_check.message).to include('0/2 found')
    end

    it 'returns ok when all prompt files exist' do
      prompts_dir = File.join(tmpdir, '.claude-on-rails', 'prompts')
      FileUtils.mkdir_p(prompts_dir)
      File.write(File.join(prompts_dir, 'architect.md'), 'prompt')
      File.write(File.join(prompts_dir, 'models.md'), 'prompt')

      swarm_config = {
        'swarm' => {
          'main' => 'architect',
          'instances' => {
            'architect' => {
              'description' => 'Main architect',
              'prompt_file' => '.claude-on-rails/prompts/architect.md'
            },
            'models' => {
              'description' => 'Models agent',
              'prompt_file' => '.claude-on-rails/prompts/models.md'
            }
          }
        }
      }
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_config))

      results = doctor.run
      prompt_check = results.find { |r| r.name == 'Prompt files' }

      expect(prompt_check.status).to eq(:ok)
      expect(prompt_check.message).to eq('2/2 found')
    end

    it 'returns ok when no prompt files are configured' do
      results = doctor.run
      prompt_check = results.find { |r| r.name == 'Prompt files' }

      expect(prompt_check.status).to eq(:ok)
      expect(prompt_check.message).to eq('no prompt files configured')
    end
  end

  describe 'claude-swarm checks' do
    it 'returns error when claude-swarm not installed' do
      allow(doctor).to receive(:claude_swarm_available?).and_return(false)
      allow(doctor).to receive(:claude_swarm_version).and_return(nil)

      results = doctor.run
      install_check = results.find { |r| r.name == 'claude-swarm installed' }

      expect(install_check.status).to eq(:error)
      expect(install_check.message).to include('not found')
    end

    it 'returns warning when claude-swarm version is below 1.0' do
      allow(doctor).to receive(:claude_swarm_version).and_return('0.9.5')

      results = doctor.run
      version_check = results.find { |r| r.name == 'claude-swarm version' }

      expect(version_check.status).to eq(:warning)
      expect(version_check.message).to include('recommend >= 1.0')
    end
  end

  describe 'Ruby version check' do
    it 'returns ok for current Ruby version' do
      results = doctor.run
      ruby_check = results.find { |r| r.name == 'Ruby version' }

      expect(ruby_check.status).to eq(:ok)
      expect(ruby_check.message).to eq(RUBY_VERSION)
    end
  end

  describe 'Rails version check' do
    it 'returns error when Rails version not detected' do
      FileUtils.rm_f(File.join(tmpdir, 'Gemfile.lock'))

      results = doctor.run
      rails_check = results.find { |r| r.name == 'Rails version' }

      expect(rails_check.status).to eq(:error)
      expect(rails_check.message).to include('not detected')
    end

    it 'returns ok when Rails version is sufficient' do
      results = doctor.run
      rails_check = results.find { |r| r.name == 'Rails version' }

      expect(rails_check.status).to eq(:ok)
    end
  end

  private

  def write_valid_swarm_config
    swarm_config = {
      'swarm' => {
        'main' => 'architect',
        'instances' => {
          'architect' => { 'description' => 'Main architect' },
          'models' => { 'description' => 'Models agent' }
        }
      }
    }
    File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_config))
  end

  def write_gemfile_lock
    lockfile_content = <<~LOCK
      GEM
        remote: https://rubygems.org/
        specs:
          rails (7.1.0)
    LOCK
    File.write(File.join(tmpdir, 'Gemfile.lock'), lockfile_content)
  end
end
