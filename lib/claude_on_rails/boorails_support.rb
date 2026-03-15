# frozen_string_literal: true

module ClaudeOnRails
  # Support module for BooRails security skills integration
  module BoorailsSupport
    BOORAILS_HOME = File.expand_path('~/.boorails')
    CLAUDE_SKILLS_DIR = File.expand_path('~/.claude/skills')

    class << self
      # Check if BooRails is installed
      def available?
        security_skill_available?
      end

      # Check if the rails-security skill is available
      def security_skill_available?
        File.directory?(boorails_security_path) || File.directory?(claude_skills_security_path)
      end

      # Return the path to the security audit script
      def security_audit_script
        boorails_script = File.join(boorails_security_path, 'scripts', 'run_security_audit.sh')
        return boorails_script if File.exist?(boorails_script)

        claude_script = File.join(claude_skills_security_path, 'scripts', 'run_security_audit.sh')
        return claude_script if File.exist?(claude_script)

        nil
      end

      # Return the path to the security references directory
      def security_references_path
        boorails_refs = File.join(boorails_security_path, 'references')
        return boorails_refs if File.directory?(boorails_refs)

        claude_refs = File.join(claude_skills_security_path, 'references')
        return claude_refs if File.directory?(claude_refs)

        nil
      end

      # List available BooRails skills
      def available_skills
        skills = []
        %w[rails-security rails-diagnose rails-quality-gates
           rails-implementation-safety rails-alternatives rails-fun-dx].each do |skill|
          skills << skill if skill_available?(skill)
        end
        skills
      end

      # Generate installation instructions
      def installation_instructions
        <<~INSTRUCTIONS
          Install BooRails for security auditing:
            bash -lc 'set -euo pipefail; REPO="$HOME/.boorails"; \\
              [ -d "$REPO/.git" ] || git clone https://github.com/kurenn/boorails.git "$REPO"; \\
              git -C "$REPO" pull --ff-only origin main; \\
              "$REPO"/install_skills_codex_claude.sh --target claude --force'
        INSTRUCTIONS
      end

      private

      def boorails_security_path
        File.join(BOORAILS_HOME, 'rails-security')
      end

      def claude_skills_security_path
        File.join(CLAUDE_SKILLS_DIR, 'rails-security')
      end

      def skill_available?(skill_name)
        File.directory?(File.join(BOORAILS_HOME, skill_name)) ||
          File.directory?(File.join(CLAUDE_SKILLS_DIR, skill_name))
      end
    end
  end
end
