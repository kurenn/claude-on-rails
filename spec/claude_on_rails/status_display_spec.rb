# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'claude_on_rails/status_display'

RSpec.describe ClaudeOnRails::StatusDisplay do
  let(:tmpdir) { Dir.mktmpdir }
  let(:display) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  before do
    # Stub external tool checks to avoid system calls in tests
    allow(ClaudeOnRails::MCPSupport).to receive(:available?).and_return(false)
    allow(display).to receive(:dev_mcp_available?).and_return(false)
    allow(display).to receive(:boorails_available?).and_return(false)
    allow(display).to receive(:detect_boorails_tools).and_return([])

    # Create minimal project structure
    FileUtils.mkdir_p(File.join(tmpdir, 'config', 'locales'))
    File.write(File.join(tmpdir, 'config', 'database.yml'), "development:\n  adapter: sqlite3")
    File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'")
  end

  describe '#run' do
    it 'prints the full status output without errors' do
      output = capture_output { display.run }

      expect(output).to include("ClaudeOnRails Status")
      expect(output).to include("Project Analysis:")
      expect(output).to include("Detected Features:")
      expect(output).to include("External Tools:")
      expect(output).to include("Custom Patterns:")
      expect(output).to include("Swarm Configuration:")
    end

    it 'displays project type as Full-stack Rails by default' do
      output = capture_output { display.run }

      expect(output).to include("Project type:     Full-stack Rails")
    end

    it 'displays API-only when detected' do
      FileUtils.mkdir_p(File.join(tmpdir, 'config'))
      File.write(
        File.join(tmpdir, 'config', 'application.rb'),
        "module App\n  class Application < Rails::Application\n    config.api_only = true\n  end\nend"
      )

      output = capture_output { display.run }

      expect(output).to include("Project type:     API-only")
    end

    it 'displays database type' do
      output = capture_output { display.run }

      expect(output).to include("Database:         sqlite3")
    end

    it 'detects postgresql database' do
      File.write(File.join(tmpdir, 'config', 'database.yml'), "development:\n  adapter: postgresql")

      output = capture_output { display.run }

      expect(output).to include("Database:         postgresql")
    end

    it 'detects test framework' do
      FileUtils.mkdir_p(File.join(tmpdir, 'spec'))

      output = capture_output { display.run }

      expect(output).to include("Test framework:   RSpec")
    end

    it 'shows None detected when no test framework' do
      output = capture_output { display.run }

      expect(output).to include("Test framework:   None detected")
    end

    it 'displays detected features' do
      File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'devise'\ngem 'turbo-rails'")

      output = capture_output { display.run }

      expect(output).to include("Devise:           Yes")
      expect(output).to include("Turbo/Stimulus:   Yes")
      expect(output).to include("Sidekiq:          No")
    end

    it 'detects tailwind' do
      File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'tailwindcss-rails'")

      output = capture_output { display.run }

      expect(output).to include("Tailwind:         Yes")
    end

    it 'detects view_component' do
      File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'view_component'")

      output = capture_output { display.run }

      expect(output).to include("ViewComponent:    Yes")
    end

    it 'detects i18n when multiple locale files exist' do
      File.write(File.join(tmpdir, 'config', 'locales', 'en.yml'), "en:\n  hello: Hello")
      File.write(File.join(tmpdir, 'config', 'locales', 'es.yml'), "es:\n  hello: Hola")

      output = capture_output { display.run }

      expect(output).to include("I18n:             Yes")
    end

    it 'shows i18n as No with only default locale' do
      File.write(File.join(tmpdir, 'config', 'locales', 'en.yml'), "en:\n  hello: Hello")

      output = capture_output { display.run }

      expect(output).to include("I18n:             No")
    end
  end

  describe 'external tools' do
    it 'shows Rails MCP Server as Available when installed' do
      allow(ClaudeOnRails::MCPSupport).to receive(:available?).and_return(true)

      output = capture_output { display.run }

      expect(output).to include("Rails MCP Server: Available")
    end

    it 'shows Rails MCP Server as Not installed when missing' do
      output = capture_output { display.run }

      expect(output).to include("Rails MCP Server: Not installed")
    end

    it 'shows BooRails as Available with tools' do
      allow(display).to receive(:boorails_available?).and_return(true)
      allow(display).to receive(:detect_boorails_tools).and_return(%w[rails-security rails-diagnose])

      output = capture_output { display.run }

      expect(output).to include("BooRails:         Available (rails-security, rails-diagnose)")
    end
  end

  describe 'custom patterns' do
    it 'detects service objects directory' do
      FileUtils.mkdir_p(File.join(tmpdir, 'app', 'services'))

      output = capture_output { display.run }

      expect(output).to include("Service objects Yes (app/services)")
    end

    it 'shows No for missing pattern directories' do
      output = capture_output { display.run }

      expect(output).to include("Service objects No")
      expect(output).to include("Form objects    No")
    end
  end

  describe 'swarm configuration' do
    it 'shows missing when no config file exists' do
      output = capture_output { display.run }

      expect(output).to include("Config file:      claude-swarm.yml (missing)")
      expect(output).to include("Agents configured: none")
    end

    it 'shows configured agents when config exists' do
      swarm_yml = {
        'swarm' => {
          'name' => 'Rails Development Team',
          'main' => 'architect',
          'instances' => {
            'architect' => { 'description' => 'Main architect' },
            'models' => { 'description' => 'Models agent' },
            'controllers' => { 'description' => 'Controllers agent' }
          }
        }
      }
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_yml))

      output = capture_output { display.run }

      expect(output).to include("Config file:      claude-swarm.yml (exists)")
      expect(output).to include("Agents configured: architect, models, controllers")
    end

    it 'shows prompt file counts' do
      swarm_yml = { 'swarm' => { 'instances' => { 'architect' => {} } } }
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_yml))

      prompts_dir = File.join(tmpdir, '.claude-on-rails', 'prompts')
      FileUtils.mkdir_p(prompts_dir)
      File.write(File.join(prompts_dir, 'architect.md'), 'prompt')
      File.write(File.join(prompts_dir, 'models.md'), 'prompt')

      output = capture_output { display.run }

      expect(output).to include("Prompt files:     2/11 present")
    end
  end

  describe 'recommendations' do
    it 'suggests installing Rails MCP Server when not available' do
      output = capture_output { display.run }

      expect(output).to include("Install Rails MCP Server for enhanced documentation access")
    end

    it 'suggests installing BooRails when not available' do
      output = capture_output { display.run }

      expect(output).to include("Install BooRails for security auditing")
    end

    it 'does not suggest MCP Server when already available' do
      allow(ClaudeOnRails::MCPSupport).to receive(:available?).and_return(true)

      output = capture_output { display.run }

      expect(output).not_to include("Install Rails MCP Server")
    end

    it 'suggests running generator when no swarm config exists' do
      output = capture_output { display.run }

      expect(output).to include("Run 'rails generate claude_on_rails:swarm' to create swarm configuration")
    end

    it 'suggests adding GraphQL agent when gem detected but agent missing' do
      File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'graphql'")
      swarm_yml = { 'swarm' => { 'instances' => { 'architect' => {} } } }
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_yml))

      output = capture_output { display.run }

      expect(output).to include("Consider adding GraphQL agent")
    end
  end

  describe '#show_agents' do
    it 'lists configured agents' do
      swarm_yml = {
        'swarm' => {
          'instances' => {
            'architect' => {},
            'models' => {},
            'tests' => {}
          }
        }
      }
      File.write(File.join(tmpdir, 'claude-swarm.yml'), YAML.dump(swarm_yml))

      output = capture_output { display.show_agents }

      expect(output).to include("Configured agents: architect, models, tests")
    end

    it 'shows message when no config exists' do
      output = capture_output { display.show_agents }

      expect(output).to include("No claude-swarm.yml found")
    end
  end

  private

  def capture_output
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = STDOUT
  end
end
