# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-03-16

### Added
- **Database agent**: Schema design, query optimization, N+1 detection, and EXPLAIN analysis (read-only)
- **Performance agent**: Application profiling, bottleneck detection, and caching strategy (read-only)
- **Design Review agent**: UX/UI critique powered by 6 design personas — Jony Ive, Amir Salihefendic, Jesse Patel, Joe Gebbia, Katie Dill, and The Notion Designer (read-only, full-stack only)
- **Documentation agent**: YARD docs, README maintenance, changelog, ADRs, and OpenAPI/GraphQL schema docs
- **I18n agent**: Internationalization support for translations, locale management, and pluralization
- **Custom agent support**: Define your own agents in `.claude-on-rails/custom_agents.yml` with validation and reserved name protection
- **Hooks support**: `--hooks` flag adds before/after hooks to agents (migration status for models, test run for tests)
- **GitHub Actions CI generator**: `rails generate claude_on_rails:ci` creates a workflow for automated PR reviews via the swarm
- **Session management rake tasks**: `claude_on_rails:sessions`, `sessions:cleanup`, and `sessions:size` for managing `.claude-swarm/` session data
- **Doctor task**: `rake claude_on_rails:doctor` validates setup with diagnostic checks
- **Upgrade task**: `rake claude_on_rails:upgrade` migrates config from older versions (MCP placement, missing agents, prompt files)
- **`--dry-run` flag**: Preview what the swarm generator would create without writing files
- **Per-agent MCP distribution**: Rails MCP Server distributed to architect, models, controllers, views, and tests agents
- **Dynamic architect prompt**: ERB-based architect prompt with project-specific context

### Changed
- MCP servers moved from swarm level to individual agent instances (claude-swarm 1.0 requirement)
- Models agent description updated to focus on associations and validations (database concerns moved to database agent)
- Tailwind, database, and design_review agents are now leaf agents with no outbound connections (fixes circular dependency errors)
- Cost-optimized mode (`--cost-optimized`) now includes database, performance, design_review, and documentation agents on sonnet

### Fixed
- Circular dependency errors: removed bidirectional connections between models↔database, views↔tailwind, and design_review→views/tailwind/stimulus

## [0.3.0] - 2026-03-14

### Changed
- Updated `claude_swarm` dependency from `~> 0.1` to `~> 1.0` to support claude-swarm 1.0.x

### Fixed
- Moved MCP server configuration from swarm level to architect instance level, fixing MCP servers being silently ignored by claude-swarm

## [0.2.1] - 2025-07-03

### Fixed
- Fixed tests prompt not being rendered correctly

## [0.2.0] - 2025-01-02

### Added
- Rails MCP Server integration for enhanced documentation access
- Interactive setup wizard with `rails claude_on_rails:setup_mcp`
- Status checking with `rails claude_on_rails:mcp_status`
- Automated MCP setup during swarm generation
- Post-install message with setup instructions
- Comprehensive SETUP.md documentation

### Changed
- Rails MCP Server is now a Ruby gem (not npm package)
- MCP configuration automatically added to swarm.yml when available
- All agent prompts enhanced with MCP-specific guidance
- Simplified setup process - just press Y during generation

### Fixed
- RDoc version conflicts during gem installation
- Use --no-document flag to avoid documentation generation issues
- Improved MCP availability detection

## [0.1.5] - 2025-01-27

### Fixed
- Fixed rake tasks not loading in Rails applications
- Added explicit require for rails/railtie in railtie.rb
- Changed Rails detection to check for Rails::Railtie instead of Rails
- Removed circular dependency in rake task file

## [0.1.4] - 2025-01-27

### Fixed
- Fixed CLAUDE.md overwriting user's existing directives
- Now uses Claude's file reference syntax (@file) to include context
- Fixed swarm configuration filename (claude-swarm.yml not swarm.yml)
- Updated documentation to clarify prompts vs commands
- Improved generator to preserve existing CLAUDE.md content

### Changed
- ClaudeOnRails context now stored in `.claude-on-rails/context.md`
- CLAUDE.md uses file references instead of appending content
- Clearer distinction between shell commands and Claude prompts
- Updated .gitignore to include `.claude-swarm/` directory

## [0.1.3] - 2025-01-26

### Fixed
- Only create swarm agents for directories that actually exist
- Changed model from full model name to claude-swarm compatible names (opus/haiku/sonnet)
- Fixed controllers connections to only include services if directory exists

### Changed
- Default model is now "opus" for all agents
- Generator now shows which agents will be created during analysis

### Improved
- Swarm configuration template now checks for directory existence before creating agents
- Better handling of optional directories like app/services, app/jobs, etc.

## [0.1.2] - 2025-01-26

### Fixed
- Fixed generator requiring claude_on_rails module
- Changed generated filename from swarm.yml to claude-swarm.yml (expected by claude-swarm CLI)
- Removed incorrect "orchestrate" command from documentation
- Fixed installation instructions (removed redundant gem install step)
- Added missing prompt templates for all agent types
- Corrected prompt syntax examples to use > prefix

### Added
- Created prompt templates for views, api, jobs, devops, graphql, and stimulus agents

## [0.1.1] - 2025-01-26

### Fixed
- Fixed dependency on claude_swarm gem (correct name with underscore)
- Updated documentation to clarify installation requirements

## [0.1.0] - 2025-01-26

### Added
- Initial release of ClaudeOnRails
- Rails generator for creating swarm configurations
- Project structure analyzer to detect Rails patterns
- Intelligent agent topology based on project type
- Support for API-only and full-stack Rails applications
- Agent-specific prompts for different Rails domains
- Integration with claude-swarm for orchestration
- Automatic detection of testing frameworks (RSpec/Minitest)
- GraphQL and Turbo/Stimulus detection
- Customizable swarm configurations

### Architecture
- Leverages claude-swarm instead of manual persona management
- Agents work in specific directories (MVC separation)
- Automatic task delegation based on context
- Natural language interface for development tasks