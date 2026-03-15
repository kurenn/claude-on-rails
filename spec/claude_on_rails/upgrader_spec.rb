# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'claude_on_rails/upgrader'

RSpec.describe ClaudeOnRails::Upgrader do
  let(:tmpdir) { Dir.mktmpdir }
  let(:upgrader) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe '#run' do
    context 'when config file is missing' do
      it 'reports no config file found' do
        report = upgrader.run

        expect(report[:issues]).to include(
          hash_including(type: :error, message: /No claude-swarm\.yml found/)
        )
        expect(report[:config_modified]).to be false
      end
    end

    context 'when config file has invalid YAML' do
      before do
        File.write(File.join(tmpdir, 'claude-swarm.yml'), "---\nkey: [unclosed")
      end

      it 'reports YAML syntax error' do
        report = upgrader.run

        expect(report[:issues]).to include(
          hash_including(type: :error, message: /invalid YAML syntax/)
        )
      end
    end

    context 'when config is already correct' do
      before do
        config = {
          'swarm' => {
            'name' => 'Rails Development Team',
            'main' => 'architect',
            'instances' => {
              'architect' => {
                'description' => 'Main architect',
                'mcps' => { 'rails-mcp' => { 'command' => 'rails-mcp' } }
              },
              'models' => { 'description' => 'Models agent' }
            }
          }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
      end

      it 'reports no fixes needed' do
        report = upgrader.run

        expect(report[:fixes]).to be_empty
        expect(report[:config_modified]).to be false
      end
    end

    context 'with swarm-level MCPs' do
      let(:config) do
        {
          'swarm' => {
            'name' => 'Rails Development Team',
            'main' => 'architect',
            'mcps' => {
              'rails-mcp' => { 'command' => 'rails-mcp-server' }
            },
            'instances' => {
              'architect' => {
                'description' => 'Main architect',
                'directory' => '.'
              },
              'models' => {
                'description' => 'Models agent',
                'directory' => './app/models'
              }
            }
          }
        }
      end

      before do
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
      end

      it 'detects swarm-level MCPs' do
        report = upgrader.run

        expect(report[:fixes]).to include(/MCP servers moved from swarm level to architect/)
      end

      it 'moves MCPs to architect instance level' do
        upgrader.run
        upgrader.apply!

        updated = YAML.safe_load_file(File.join(tmpdir, 'claude-swarm.yml'))
        architect = updated.dig('swarm', 'instances', 'architect')
        expect(architect['mcps']).to eq({ 'rails-mcp' => { 'command' => 'rails-mcp-server' } })
        expect(updated['swarm']).not_to have_key('mcps')
      end

      it 'merges with existing architect MCPs' do
        config['swarm']['instances']['architect']['mcps'] = {
          'existing-mcp' => { 'command' => 'existing' }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))

        upgrader.run
        upgrader.apply!

        updated = YAML.safe_load_file(File.join(tmpdir, 'claude-swarm.yml'))
        architect_mcps = updated.dig('swarm', 'instances', 'architect', 'mcps')
        expect(architect_mcps).to include('existing-mcp', 'rails-mcp')
      end

      it 'preserves all other YAML content' do
        upgrader.run
        upgrader.apply!

        updated = YAML.safe_load_file(File.join(tmpdir, 'claude-swarm.yml'))
        expect(updated.dig('swarm', 'name')).to eq('Rails Development Team')
        expect(updated.dig('swarm', 'instances', 'models', 'description')).to eq('Models agent')
      end
    end

    context 'with custom main agent' do
      before do
        config = {
          'swarm' => {
            'main' => 'lead',
            'mcps' => { 'mcp1' => { 'command' => 'cmd' } },
            'instances' => {
              'lead' => { 'description' => 'Lead agent' }
            }
          }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
      end

      it 'moves MCPs to the actual main agent' do
        report = upgrader.run

        expect(report[:fixes]).to include(/MCP servers moved from swarm level to lead/)
      end
    end

    context 'with missing design_review agent in full-stack app' do
      before do
        config = {
          'swarm' => {
            'instances' => {
              'architect' => { 'description' => 'Main architect' },
              'views' => { 'description' => 'Views agent' }
            }
          }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
      end

      it 'suggests adding design_review agent' do
        report = upgrader.run

        expect(report[:issues]).to include(
          hash_including(type: :suggestion, message: /design_review/)
        )
      end
    end

    context 'with api-only app' do
      before do
        config = {
          'swarm' => {
            'instances' => {
              'architect' => { 'description' => 'Main architect' }
            }
          }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
        FileUtils.mkdir_p(File.join(tmpdir, 'config'))
        File.write(
          File.join(tmpdir, 'config', 'application.rb'),
          "module App\n  class Application < Rails::Application\n    config.api_only = true\n  end\nend"
        )
      end

      it 'does not suggest design_review agent' do
        report = upgrader.run

        expect(report[:issues]).not_to include(
          hash_including(message: /design_review/)
        )
      end
    end

    context 'with missing prompt files' do
      before do
        config = {
          'swarm' => {
            'instances' => {
              'architect' => {
                'prompt_file' => '.claude-on-rails/prompts/architect.md'
              },
              'models' => {
                'prompt_file' => '.claude-on-rails/prompts/models.md'
              }
            }
          }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
      end

      it 'warns about missing prompt files' do
        report = upgrader.run

        expect(report[:issues]).to include(
          hash_including(type: :warning, message: /Missing prompt files/)
        )
      end

      it 'does not warn when prompt files exist' do
        prompts_dir = File.join(tmpdir, '.claude-on-rails', 'prompts')
        FileUtils.mkdir_p(prompts_dir)
        File.write(File.join(prompts_dir, 'architect.md'), 'prompt')
        File.write(File.join(prompts_dir, 'models.md'), 'prompt')

        report = upgrader.run

        expect(report[:issues]).not_to include(
          hash_including(message: /Missing prompt files/)
        )
      end
    end
  end

  describe '#apply!' do
    context 'when config was modified' do
      before do
        config = {
          'swarm' => {
            'main' => 'architect',
            'mcps' => { 'mcp1' => { 'command' => 'cmd' } },
            'instances' => {
              'architect' => { 'description' => 'Architect' }
            }
          }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
      end

      it 'creates a backup before modifying' do
        upgrader.run
        upgrader.apply!

        expect(File.exist?(File.join(tmpdir, 'claude-swarm.yml.backup'))).to be true
      end

      it 'backup contains original content' do
        original = File.read(File.join(tmpdir, 'claude-swarm.yml'))
        upgrader.run
        upgrader.apply!

        backup = File.read(File.join(tmpdir, 'claude-swarm.yml.backup'))
        expect(backup).to eq(original)
      end
    end

    context 'when config was not modified' do
      before do
        config = {
          'swarm' => {
            'instances' => {
              'architect' => { 'description' => 'Architect' }
            }
          }
        }
        File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(config))
      end

      it 'does not create a backup' do
        upgrader.run
        upgrader.apply!

        expect(File.exist?(File.join(tmpdir, 'claude-swarm.yml.backup'))).to be false
      end
    end
  end
end
