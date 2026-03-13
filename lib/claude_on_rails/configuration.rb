# frozen_string_literal: true

module ClaudeOnRails
  class Configuration
    attr_accessor :default_model, :vibe_mode, :session_directory, :log_directory, :agent_models

    def initialize
      @default_model = 'opus'
      @vibe_mode = true
      @session_directory = '.claude-on-rails/sessions'
      @log_directory = '.claude-on-rails/logs'
      @agent_models = {}
    end

    def model_for(agent_name)
      agent_models[agent_name.to_s] || default_model
    end

    def to_h
      {
        default_model: default_model,
        vibe_mode: vibe_mode,
        session_directory: session_directory,
        log_directory: log_directory,
        agent_models: agent_models
      }
    end
  end
end
