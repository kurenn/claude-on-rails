# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'erb'

RSpec.describe 'CiGenerator' do
  let(:tmpdir) { Dir.mktmpdir }
  let(:template_path) do
    File.expand_path(
      '../../lib/generators/claude_on_rails/ci/templates/claude_review.yml.erb',
      __dir__
    )
  end

  after { FileUtils.rm_rf(tmpdir) }

  def render_template(review_agents: %w[security design_review])
    options = { review_agents: review_agents }
    ERB.new(File.read(template_path), trim_mode: '-').result(binding)
  end

  describe 'workflow template with default agents' do
    subject(:content) { render_template }

    it 'includes the default review agents' do
      expect(content).to include('security')
      expect(content).to include('design_review')
    end

    it 'includes the ANTHROPIC_API_KEY secret reference' do
      expect(content).to include('ANTHROPIC_API_KEY')
      expect(content).to include('secrets.ANTHROPIC_API_KEY')
    end

    it 'triggers on pull_request events' do
      expect(content).to include('pull_request')
      expect(content).to include('opened')
      expect(content).to include('synchronize')
    end

    it 'includes the checkout step with full history' do
      expect(content).to include('actions/checkout@v4')
      expect(content).to include('fetch-depth: 0')
    end

    it 'includes Ruby setup with .ruby-version' do
      expect(content).to include('ruby/setup-ruby@v1')
      expect(content).to include('ruby-version: .ruby-version')
    end

    it 'installs claude-swarm with version constraint' do
      expect(content).to include("gem install claude_swarm --version '~> 1.0'")
    end

    it 'sets correct permissions' do
      expect(content).to include('contents: read')
      expect(content).to include('pull-requests: write')
    end

    it 'uses claude-swarm start with -p flag for non-interactive mode' do
      expect(content).to include('claude-swarm start --stream-logs -p')
    end

    it 'captures output to review-output.txt' do
      expect(content).to include('tee review-output.txt')
      expect(content).to include("readFileSync('review-output.txt'")
    end

    it 'uses git diff --name-only instead of full diff' do
      expect(content).to include('git diff --name-only')
    end
  end

  describe 'workflow template with custom agents' do
    subject(:content) { render_template(review_agents: %w[security performance]) }

    it 'includes the custom agents in the prompt' do
      expect(content).to include('security, performance')
    end

    it 'does not include the default design_review agent' do
      expect(content).not_to include('design_review')
    end
  end

  describe 'generator class' do
    let(:generator_path) do
      File.expand_path(
        '../../lib/generators/claude_on_rails/ci/ci_generator.rb',
        __dir__
      )
    end

    it 'exists at the expected path' do
      expect(File.exist?(generator_path)).to be true
    end

    it 'defines the correct class structure' do
      content = File.read(generator_path)
      expect(content).to include('module ClaudeOnRails')
      expect(content).to include('module Generators')
      expect(content).to include('class CiGenerator < Rails::Generators::Base')
    end

    it 'creates workflow at the correct destination path' do
      content = File.read(generator_path)
      expect(content).to include('.github/workflows/claude-review.yml')
    end

    it 'defines the review_agents class option with correct defaults' do
      content = File.read(generator_path)
      expect(content).to include('class_option :review_agents')
      expect(content).to include('%w[security design_review]')
    end
  end
end
