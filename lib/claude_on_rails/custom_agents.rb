# frozen_string_literal: true

require 'yaml'

module ClaudeOnRails
  class CustomAgents
    REQUIRED_FIELDS = %w[description].freeze
    OPTIONAL_FIELDS = %w[directory connections allowed_tools model prompt_file].freeze
    VALID_FIELDS = (REQUIRED_FIELDS + OPTIONAL_FIELDS).freeze
    DEFAULT_ALLOWED_TOOLS = %w[Read Edit Write Bash Grep Glob LS].freeze
    CONFIG_FILENAME = '.claude-on-rails/custom_agents.yml'

    attr_reader :root_path

    def initialize(root_path_or_analysis)
      @root_path = if root_path_or_analysis.is_a?(Hash)
                     root_path_or_analysis[:root_path] || '.'
                   else
                     root_path_or_analysis.to_s
                   end
    end

    def load
      file_path = File.join(root_path, CONFIG_FILENAME)
      return {} unless File.exist?(file_path)

      raw = YAML.safe_load_file(file_path)
      return {} unless raw.is_a?(Hash) && raw['agents'].is_a?(Hash)

      validate_and_normalize(raw['agents'])
    end

    def self.load_from_file(root_path)
      new(root_path.to_s).load
    end

    private

    def validate_and_normalize(agents)
      result = {}

      agents.each do |name, config|
        raise Error, "Custom agent '#{name}' must be a hash of configuration options" unless config.is_a?(Hash)

        REQUIRED_FIELDS.each do |field|
          raise Error, "Custom agent '#{name}' is missing required field '#{field}'" unless config.key?(field)
        end

        invalid_fields = config.keys - VALID_FIELDS
        unless invalid_fields.empty?
          raise Error,
                "Custom agent '#{name}' has invalid fields: #{invalid_fields.join(', ')}"
        end

        normalized = {
          description: config['description'],
          directory: config['directory'] || '.',
          allowed_tools: config['allowed_tools'] || DEFAULT_ALLOWED_TOOLS.dup
        }

        normalized[:connections] = config['connections'] if config['connections']&.any?
        normalized[:prompt_file] = config['prompt_file'] if config['prompt_file']
        normalized[:model] = config['model'] if config['model']

        result[name.to_sym] = normalized
      end

      result
    end
  end
end
