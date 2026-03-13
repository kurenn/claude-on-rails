# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe ClaudeOnRails::ProjectAnalyzer do
  let(:tmpdir) { Dir.mktmpdir }
  let(:analyzer) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe '#analyze' do
    it 'returns a hash with expected keys' do
      result = analyzer.analyze

      expect(result).to be_a(Hash)
      expect(result).to include(
        :api_only,
        :test_framework,
        :has_graphql,
        :has_turbo,
        :has_devise,
        :has_sidekiq,
        :has_tailwind,
        :has_view_component,
        :has_i18n,
        :javascript_framework,
        :database,
        :deployment,
        :custom_patterns,
        :has_boorails
      )
    end

    context 'with a standard Rails app' do
      before do
        # Create minimal Rails structure
        FileUtils.mkdir_p(File.join(tmpdir, 'config'))
        File.write(File.join(tmpdir, 'config', 'application.rb'),
                   "module MyApp\n  class Application < Rails::Application\n  end\nend")
        File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'")
      end

      it "detects it's not API-only" do
        expect(analyzer.analyze[:api_only]).to be false
      end
    end

    context 'with an API-only Rails app' do
      before do
        FileUtils.mkdir_p(File.join(tmpdir, 'config'))
        File.write(File.join(tmpdir, 'config', 'application.rb'),
                   "module MyApp\n  class Application < Rails::Application\n    config.api_only = true\n  end\nend")
      end

      it 'detects API-only configuration' do
        expect(analyzer.analyze[:api_only]).to be true
      end
    end

    context 'test framework detection' do
      it 'detects RSpec' do
        FileUtils.mkdir_p(File.join(tmpdir, 'spec'))
        expect(analyzer.analyze[:test_framework]).to eq 'RSpec'
      end

      it 'detects Minitest' do
        FileUtils.mkdir_p(File.join(tmpdir, 'test'))
        expect(analyzer.analyze[:test_framework]).to eq 'Minitest'
      end

      it 'returns nil when no test framework is found' do
        expect(analyzer.analyze[:test_framework]).to be_nil
      end
    end

    context 'gem detection' do
      before do
        File.write(File.join(tmpdir, 'Gemfile'), gemfile_content)
      end

      context 'with GraphQL' do
        let(:gemfile_content) { "gem 'rails'\ngem 'graphql'" }

        it 'detects GraphQL' do
          expect(analyzer.analyze[:has_graphql]).to be true
        end
      end

      context 'with Turbo' do
        let(:gemfile_content) { "gem 'rails'\ngem 'turbo-rails'" }

        it 'detects Turbo' do
          expect(analyzer.analyze[:has_turbo]).to be true
        end
      end

      context 'with Devise' do
        let(:gemfile_content) { "gem 'rails'\ngem 'devise'" }

        it 'detects Devise' do
          expect(analyzer.analyze[:has_devise]).to be true
        end
      end

      context 'with Tailwind via tailwindcss-rails gem' do
        let(:gemfile_content) { "gem 'rails'\ngem 'tailwindcss-rails'" }

        it 'detects Tailwind' do
          expect(analyzer.analyze[:has_tailwind]).to be true
        end
      end

      context 'with Tailwind via tailwindcss-ruby gem' do
        let(:gemfile_content) { "gem 'rails'\ngem 'tailwindcss-ruby'" }

        it 'detects Tailwind' do
          expect(analyzer.analyze[:has_tailwind]).to be true
        end
      end
    end

    context 'Tailwind detection via config files' do
      it 'detects config/tailwind.config.js' do
        FileUtils.mkdir_p(File.join(tmpdir, 'config'))
        File.write(File.join(tmpdir, 'config', 'tailwind.config.js'), '{}')
        expect(analyzer.analyze[:has_tailwind]).to be true
      end

      it 'detects tailwind.config.js at root' do
        File.write(File.join(tmpdir, 'tailwind.config.js'), '{}')
        expect(analyzer.analyze[:has_tailwind]).to be true
      end

      it 'detects tailwind.config.ts at root' do
        File.write(File.join(tmpdir, 'tailwind.config.ts'), '{}')
        expect(analyzer.analyze[:has_tailwind]).to be true
      end

      it 'detects application.tailwind.css entry point' do
        FileUtils.mkdir_p(File.join(tmpdir, 'app', 'assets', 'stylesheets'))
        File.write(File.join(tmpdir, 'app', 'assets', 'stylesheets', 'application.tailwind.css'),
                   '@import "tailwindcss";')
        expect(analyzer.analyze[:has_tailwind]).to be true
      end

      it 'returns false when no Tailwind is present' do
        expect(analyzer.analyze[:has_tailwind]).to be false
      end
    end

    context 'ViewComponent detection' do
      context 'with view_component in Gemfile' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'view_component'")
        end

        it 'detects ViewComponent' do
          expect(analyzer.analyze[:has_view_component]).to be true
        end
      end

      context 'with app/components directory' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'")
          FileUtils.mkdir_p(File.join(tmpdir, 'app', 'components'))
        end

        it 'detects ViewComponent' do
          expect(analyzer.analyze[:has_view_component]).to be true
        end
      end

      context 'without view_component' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'")
        end

        it 'does not detect ViewComponent' do
          expect(analyzer.analyze[:has_view_component]).to be false
        end
      end
    end

    context 'i18n detection' do
      context 'with multiple locale files' do
        before do
          FileUtils.mkdir_p(File.join(tmpdir, 'config', 'locales'))
          File.write(File.join(tmpdir, 'config', 'locales', 'en.yml'), "en:\n  hello: Hello")
          File.write(File.join(tmpdir, 'config', 'locales', 'es.yml'), "es:\n  hello: Hola")
        end

        it 'detects i18n' do
          expect(analyzer.analyze[:has_i18n]).to be true
        end
      end

      context 'with only default en.yml' do
        before do
          FileUtils.mkdir_p(File.join(tmpdir, 'config', 'locales'))
          File.write(File.join(tmpdir, 'config', 'locales', 'en.yml'), "en:\n  hello: Hello")
        end

        it 'does not detect i18n' do
          expect(analyzer.analyze[:has_i18n]).to be false
        end
      end

      context 'with i18n-tasks gem in Gemfile' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'i18n-tasks'")
        end

        it 'detects i18n' do
          expect(analyzer.analyze[:has_i18n]).to be true
        end
      end

      context 'with rails-i18n gem in Gemfile' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'rails-i18n'")
        end

        it 'detects i18n' do
          expect(analyzer.analyze[:has_i18n]).to be true
        end
      end

      context 'with mobility gem in Gemfile' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'mobility'")
        end

        it 'detects i18n' do
          expect(analyzer.analyze[:has_i18n]).to be true
        end
      end

      context 'with globalize gem in Gemfile' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'\ngem 'globalize'")
        end

        it 'detects i18n' do
          expect(analyzer.analyze[:has_i18n]).to be true
        end
      end

      context 'without locales directory and no i18n gems' do
        before do
          File.write(File.join(tmpdir, 'Gemfile'), "gem 'rails'")
        end

        it 'does not detect i18n' do
          expect(analyzer.analyze[:has_i18n]).to be false
        end
      end
    end

    context 'custom patterns detection' do
      it 'detects service objects directory' do
        FileUtils.mkdir_p(File.join(tmpdir, 'app', 'services'))
        patterns = analyzer.analyze[:custom_patterns]
        expect(patterns[:has_services]).to be true
      end

      it 'detects form objects directory' do
        FileUtils.mkdir_p(File.join(tmpdir, 'app', 'forms'))
        patterns = analyzer.analyze[:custom_patterns]
        expect(patterns[:has_forms]).to be true
      end
    end
  end
end
