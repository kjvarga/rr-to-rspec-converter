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

        @source_rewriter = Parser::Source::TreeRewriter.new(@source_buffer)
      end

      def transform
        root_node = @parser.parse(@source_buffer)
        unless root_node
          log "Parser saw some unparsable content, skipping...\n\n"
          return @source_rewriter.process
        end

        root_node.each_node(:send) do |node|
          target, verb, action, *args = node.children

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
            range = Parser::Source::Range.new(@source_buffer, target.loc.expression.begin_pos, node.loc.selector.end_pos)
            @source_rewriter.replace(range, 'rr_satisfy')

          # rr_satisfy => satisfy
          elsif verb == :rr_satisfy
            @source_rewriter.replace(node.loc.selector, 'satisfy')

          # RR.reset => removed
          elsif verb == :reset && target.const_type? && target.children.last == :RR
            sibling = node.root? ? nil : node.parent.children[node.sibling_index + 1]
            end_pos = sibling ? sibling.loc.column : node.loc.last_column
            @source_rewriter.remove(range(node.loc.column, end_pos))

          # any_instance_of(klass, method: return) => block with stub
          elsif verb == :any_instance_of && !args.empty?
            stubs = []
            indent = line_indent(node)
            node.each_node(:pair) do |pair|
              method_name = pair.children.first.loc.expression.source.sub(/^:/,'')
              method_result = pair.children.last.loc.expression.source
              stubs << "#{indent}  stub(o).#{method_name}.and_return(#{method_result})"
            end

            @source_rewriter.replace(node.loc.expression, "#{verb}(#{action.loc.expression.source}) do |o|\n#{stubs.join("\n")}\n#{indent}end")

          # mock => expect().to receive
          elsif verb == :mock
            expectation = 'to'

            # If there is a call to 'never' then use expect().not_to receive
            never_node = root_node.each_node(:send).find { |n| n.children[1] == :never }
            if never_node
              expectation = 'not_to'
              @source_rewriter.remove(range(never_node.children.first.loc.last_column, never_node.loc.selector.last_column))
            end

            @source_rewriter.replace(node.loc.selector, 'expect')
            method_name = node.parent.loc.selector.source
            has_args = !node.parent.children[2].nil?
            @source_rewriter.replace(node.parent.loc.selector, "#{expectation} receive(:#{method_name})#{has_args ? '.with' : ''}")

          # stub => allow().to receive
          elsif verb == :stub
            @source_rewriter.replace(node.loc.selector, 'allow')
            method_name = node.parent.loc.selector.source
            has_args = !node.parent.children[2].nil?
            @source_rewriter.replace(node.parent.loc.selector, "to receive(:#{method_name})#{has_args ? '.with' : ''}")

          # dont_allow => expect().not_to receive
          elsif verb == :dont_allow
            @source_rewriter.replace(node.loc.selector, 'expect')
            method_name = node.parent.loc.selector.source
            has_args = !node.parent.children[2].nil?
            @source_rewriter.replace(node.parent.loc.selector, "not_to receive(:#{method_name})#{has_args ? '.with' : ''}")
          end
        end

        # Process any_instance_of last
        root_node.each_node(:block) do |node|
          method_name = node.children[0].children[1]
          next unless method_name == :any_instance_of

          class_name = node.children.first.children[2].children[1].to_s

          # Process each expect or allow within the block
          node.each_node(:send) do |send_node|
            method_name = send_node.children[1]
            next unless [:expect, :allow].include?(method_name)

            @source_rewriter.replace(send_node.loc.selector, "#{method_name}_any_instance_of")
            @source_rewriter.replace(send_node.children[2].loc.expression, class_name)
          end

          # If it's a begin block, we have to go a level deeper
          first_statement = node.children[2].begin_type? ? node.children[2].children.first : node.children[2]
          last_statement = node.children[2].begin_type? ? node.children[2].children.last : node.children[2]
          @source_rewriter.remove(range(node.loc.expression.begin_pos, first_statement.loc.expression.begin_pos)) # start of block
          @source_rewriter.remove(range(last_statement.loc.expression.end_pos, node.loc.expression.end_pos)) # end of block
        end

        @source_rewriter.process
      end

      private

      def range(start_pos, end_pos)
        Parser::Source::Range.new(@source_buffer, start_pos, end_pos)
      end

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
