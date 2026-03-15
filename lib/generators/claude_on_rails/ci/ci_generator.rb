# frozen_string_literal: true

require 'rails/generators/base'

module ClaudeOnRails
  module Generators
    class CiGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      class_option :review_agents, type: :array, default: %w[security design_review],
                                   desc: 'Read-only agents to run on PRs'

      def create_workflow
        template 'claude_review.yml.erb', '.github/workflows/claude-review.yml'
      end

      def display_next_steps
        say "\nGitHub Actions workflow created!", :green
        say 'The workflow will run read-only agents on pull requests.', :cyan
        say "\nRequired secrets:", :yellow
        say '  ANTHROPIC_API_KEY - Your Anthropic API key', :cyan
        say "\nTo configure, go to your repo Settings > Secrets and variables > Actions", :cyan
      end
    end
  end
end
