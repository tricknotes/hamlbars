require 'tilt/template'

module Hamlbars
  class Template < Tilt::Template
    JS_ESCAPE_MAP = {
      "\r\n"  => '\n',
      "\n"    => '\n',
      "\r"    => '\n',
      '"'     => '\\"',
      "'"     => "\\'" }

      self.default_mime_type = 'application/javascript'

      def self.engine_initialized?
        defined? ::Haml::Engine
      end

      def initialize_engine
        require_template_library 'haml'
      end

      def prepare
        options = @options.merge(:filename => eval_file, :line => line)
        @engine = ::Haml::Engine.new(data, options)
      end

      def evaluate(scope, locals, &block)
        template = if @engine.respond_to?(:precompiled_method_return_value, true)
                     super
                   else
                     @engine.render(scope, locals, &block)
                   end
=begin
        if basename =~ /^_/
        "Handlebars.registerPartial('#{name}', '#{template.strip.gsub(/(\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }}');\n"
        else
        "App.registerTemplate('#{name}', '#{template.strip.gsub(/(\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }}');\n"
        end
=end
        "Ember.TEMPLATES[\"#{scope.logical_path.downcase.gsub(/[^a-z0-9]/, '_')}\"] = Ember.Handlebars.compile(\"#{template.strip.gsub(/(\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }}\");\n"
      end

      # Precompiled Haml source. Taken from the precompiled_with_ambles
      # method in Haml::Precompiler:
      # http://github.com/nex3/haml/blob/master/lib/haml/precompiler.rb#L111-126
      def precompiled_template(locals)
        @engine.precompiled
      end

      def precompiled_preamble(locals)
        local_assigns = super
        @engine.instance_eval do
          <<-RUBY
          begin
            extend Haml::Helpers
            _hamlout = @haml_buffer = Haml::Buffer.new(@haml_buffer, #{options_for_buffer.inspect})
            _erbout = _hamlout.buffer
            __in_erb_template = true
            _haml_locals = locals
          #{local_assigns}
        RUBY
        end
      end

      def precompiled_postamble(locals)
        @engine.instance_eval do
          <<-RUBY
          #{precompiled_method_return_value}
          ensure
            @haml_buffer = @haml_buffer.upper
          end
        RUBY
        end
      end
  end
end

module Haml
  module Helpers

    module HamlbarsExtensions
      def iterate(name, &block)
        content = capture_haml(&block)
        "{{##{name}}}#{content.strip}{{/#{name}}}"
      end
    end

    include HamlbarsExtensions
  end
end
