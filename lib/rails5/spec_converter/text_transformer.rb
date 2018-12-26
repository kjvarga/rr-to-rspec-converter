require 'parser/current'
require 'astrolabe/builder'
require 'rails5/spec_converter/test_type_identifier'
require 'rails5/spec_converter/text_transformer_options'
require 'rails5/spec_converter/hash_rewriter'

module Rails5
  module SpecConverter
    HTTP_VERBS = %i(get post put patch delete)

    class TextTransformer
      def initialize(content, options = TextTransformerOptions.new)
        @options = options
        @content = content
        @textifier = NodeTextifier.new(@content)

        @source_buffer = Parser::Source::Buffer.new('(string)')
        @source_buffer.source = @content

        ast_builder = Astrolabe::Builder.new
        @parser = Parser::CurrentRuby.new(ast_builder)

        @source_rewriter = Parser::Source::Rewriter.new(@source_buffer)
      end

      def transform
        # byebug
        root_node = @parser.parse(@source_buffer)
        unless root_node
          log "Parser saw some unparsable content, skipping...\n\n"
          return @source_rewriter.process
        end

        root_node.each_node(:send) do |node|
          target, verb, action, *args = node.children
          # byebug
          if verb == :with_any_args
            @source_rewriter.replace(node.loc.selector, 'with(any_args)')
          elsif verb == :any_times
            @source_rewriter.replace(node.loc.selector, 'at_least(:once)')
          elsif verb == :returns
            @source_rewriter.replace(node.loc.selector, 'and_return')
          elsif verb == :times && action.int_type?
            times = action.children[0]
            if times == 1
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), '.once')
            elsif times == 2
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), '.twice')
            end
          elsif verb == :at_least && action.int_type?
            times = action.children[0]
            if times == 1
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_least(:once)')
            elsif times == 2
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_least(:twice)')
            else
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), ".at_least(#{times}).times")
            end
          elsif verb == :at_most && action.int_type?
            times = action.children[0]
            if times == 1
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_most(:once)')
            elsif times == 2
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_most(:twice)')
            else
              @source_rewriter.replace(Parser::Source::Range.new(@source_buffer, target.loc.expression.end_pos, node.loc.expression.end_pos), ".at_most(#{times}).times")
            end
          elsif verb == :is_a
            @source_rewriter.replace(node.loc.selector, 'kind_of')
          elsif verb == :numeric
            @source_rewriter.replace(node.loc.selector, 'kind_of(Numeric)')

          # RR::WildcardMatchers::HashIncluding => hash_including
          elsif verb == :new && target.const_type? && target.children.last == :HashIncluding
            range = Parser::Source::Range.new(@source_buffer, target.loc.expression.begin_pos, node.loc.selector.end_pos)
            @source_rewriter.replace(range, 'hash_including')

          # RR::WildcardMatchers::Satisfy => rr_satsify
          elsif verb == :new && target.const_type? && target.children.last == :Satisfy
            # byebug
            range = Parser::Source::Range.new(@source_buffer, target.loc.expression.begin_pos, node.loc.selector.end_pos)
            @source_rewriter.replace(range, 'rr_satisfy')
          end

          # next unless args.length > 0

          # next unless target.nil? && HTTP_VERBS.include?(verb)
          # if args[0].hash_type?
          #   if args[0].children.length == 0
          #     wrap_arg(args[0], 'params')
          #   else
          #     next if looks_like_route_definition?(args[0])
          #     next if has_key?(args[0], :params)

          #     hash_rewriter = HashRewriter.new(
          #       content: @content,
          #       options: @options,
          #       hash_node: args[0],
          #       original_indent: line_indent(node)
          #     )

          #     @source_rewriter.replace(
          #       args[0].loc.expression,
          #       hash_rewriter.rewritten_params_hash
          #     ) if hash_rewriter.should_rewrite_hash?
          #   end
          # elsif args[0].nil_type? && args.length > 1
          #   nil_arg_range = Parser::Source::Range.new(
          #     @source_buffer,
          #     args[0].loc.expression.begin_pos,
          #     args[1].loc.expression.begin_pos
          #   )
          #   @source_rewriter.remove(nil_arg_range)
          # else
          #   wrap_arg(args[0], 'params')
          # end

          # wrap_extra_positional_args!(args) if args.length > 1
        end

        @source_rewriter.process
      end

      private

      def looks_like_route_definition?(hash_node)
        keys = hash_node.children.map { |pair| pair.children[0].children[0] }
        route_definition_keys = [:to, :controller]
        return true if route_definition_keys.all? { |k| keys.include?(k) }

        hash_node.children.each do |pair|
          key = pair.children[0].children[0]
          if key == :to
            if pair.children[1].str_type?
              value = pair.children[1].children[0]
              return true if value.match(/^\w+#\w+$/)
            end
          end
        end

        false
      end

      def has_kwsplat?(hash_node)
        hash_node.children.any? { |node| node.kwsplat_type? }
      end

      def has_key?(hash_node, key)
        hash_node.children.any? { |pair| pair.children[0].children[0] == key }
      end

      def wrap_extra_positional_args!(args)
        if test_type == :controller
          wrap_arg(args[1], 'session') if args[1]
          wrap_arg(args[2], 'flash') if args[2]
        end
        if test_type == :request
          wrap_arg(args[1], 'headers') if args[1]
        end
      end

      def wrap_arg(node, key)
        node_loc = node.loc.expression
        node_source = node_loc.source
        if node.hash_type? && !node_source.match(/^\s*\{.*\}$/m)
          node_source = "{ #{node_source} }"
        end
        @source_rewriter.replace(node_loc, "#{key}: #{node_source}")
      end

      def line_indent(node)
        node.loc.expression.source_line.match(/^(\s*)/)[1]
      end

      def test_type
        @test_type ||= TestTypeIdentifier.new(@content, @options).test_type
      end

      def log(str)
        return if @options.quiet?

        puts str
      end
    end
  end
end
