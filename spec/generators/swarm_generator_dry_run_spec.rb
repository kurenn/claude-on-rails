# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SwarmGenerator --dry-run' do
  let(:generator_path) do
    File.expand_path(
      '../../lib/generators/claude_on_rails/swarm/swarm_generator.rb',
      __dir__
    )
  end

  it 'defines the dry_run class option' do
    content = File.read(generator_path)
    expect(content).to include('class_option :dry_run')
    expect(content).to include("type: :boolean, default: false")
  end

  it 'guards create_swarm_config with dry_run check' do
    content = File.read(generator_path)
    expect(content).to match(/def create_swarm_config\s+return if options\[:dry_run\]/)
  end

  it 'guards create_claude_md with dry_run check' do
    content = File.read(generator_path)
    expect(content).to match(/def create_claude_md\s+return if options\[:dry_run\]/)
  end

  it 'guards create_agent_prompts with dry_run check' do
    content = File.read(generator_path)
    expect(content).to match(/def create_agent_prompts\s+return if options\[:dry_run\]/)
  end

  it 'guards update_gitignore with dry_run check' do
    content = File.read(generator_path)
    expect(content).to match(/def update_gitignore\s+return if options\[:dry_run\]/)
  end

  it 'guards display_next_steps with dry_run check' do
    content = File.read(generator_path)
    expect(content).to match(/def display_next_steps\s+return if options\[:dry_run\]/)
  end

  it 'has a display_dry_run_summary method' do
    content = File.read(generator_path)
    expect(content).to include('def display_dry_run_summary')
    expect(content).to include('[DRY RUN] No files will be written.')
  end
end
