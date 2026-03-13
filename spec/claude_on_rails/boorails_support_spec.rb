# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe ClaudeOnRails::BoorailsSupport do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  describe '.available?' do
    context 'when BooRails is installed in ~/.boorails' do
      before do
        stub_const('ClaudeOnRails::BoorailsSupport::BOORAILS_HOME', File.join(tmpdir, '.boorails'))
        FileUtils.mkdir_p(File.join(tmpdir, '.boorails', 'rails-security'))
      end

      it 'returns true' do
        expect(described_class.available?).to be true
      end
    end

    context 'when BooRails is installed in ~/.claude/skills' do
      before do
        stub_const('ClaudeOnRails::BoorailsSupport::BOORAILS_HOME', File.join(tmpdir, '.boorails'))
        stub_const('ClaudeOnRails::BoorailsSupport::CLAUDE_SKILLS_DIR', File.join(tmpdir, '.claude', 'skills'))
        FileUtils.mkdir_p(File.join(tmpdir, '.claude', 'skills', 'rails-security'))
      end

      it 'returns true' do
        expect(described_class.available?).to be true
      end
    end

    context 'when BooRails is not installed' do
      before do
        stub_const('ClaudeOnRails::BoorailsSupport::BOORAILS_HOME', File.join(tmpdir, '.boorails'))
        stub_const('ClaudeOnRails::BoorailsSupport::CLAUDE_SKILLS_DIR', File.join(tmpdir, '.claude', 'skills'))
      end

      it 'returns false' do
        expect(described_class.available?).to be false
      end
    end
  end

  describe '.security_audit_script' do
    context 'when script exists in ~/.boorails' do
      before do
        stub_const('ClaudeOnRails::BoorailsSupport::BOORAILS_HOME', File.join(tmpdir, '.boorails'))
        script_dir = File.join(tmpdir, '.boorails', 'rails-security', 'scripts')
        FileUtils.mkdir_p(script_dir)
        File.write(File.join(script_dir, 'run_security_audit.sh'), '#!/bin/bash')
      end

      it 'returns the script path' do
        expect(described_class.security_audit_script).to end_with('run_security_audit.sh')
      end
    end

    context 'when script does not exist' do
      before do
        stub_const('ClaudeOnRails::BoorailsSupport::BOORAILS_HOME', File.join(tmpdir, '.boorails'))
        stub_const('ClaudeOnRails::BoorailsSupport::CLAUDE_SKILLS_DIR', File.join(tmpdir, '.claude', 'skills'))
      end

      it 'returns nil' do
        expect(described_class.security_audit_script).to be_nil
      end
    end
  end

  describe '.available_skills' do
    before do
      stub_const('ClaudeOnRails::BoorailsSupport::BOORAILS_HOME', File.join(tmpdir, '.boorails'))
      stub_const('ClaudeOnRails::BoorailsSupport::CLAUDE_SKILLS_DIR', File.join(tmpdir, '.claude', 'skills'))
    end

    context 'when multiple skills are installed' do
      before do
        %w[rails-security rails-diagnose rails-quality-gates].each do |skill|
          FileUtils.mkdir_p(File.join(tmpdir, '.boorails', skill))
        end
      end

      it 'returns the available skills' do
        skills = described_class.available_skills
        expect(skills).to include('rails-security', 'rails-diagnose', 'rails-quality-gates')
        expect(skills).not_to include('rails-alternatives', 'rails-fun-dx')
      end
    end

    context 'when no skills are installed' do
      it 'returns an empty array' do
        expect(described_class.available_skills).to be_empty
      end
    end
  end

  describe '.installation_instructions' do
    it 'includes the clone command' do
      instructions = described_class.installation_instructions
      expect(instructions).to include('git clone')
      expect(instructions).to include('boorails')
    end
  end
end
