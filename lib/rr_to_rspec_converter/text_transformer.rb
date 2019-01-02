require 'parser/current'
require 'astrolabe/builder'
require 'rr_to_rspec_converter/test_type_identifier'
require 'rr_to_rspec_converter/text_transformer_options'
require 'rr_to_rspec_converter/hash_rewriter'

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
            @source_rewriter.replace(node.loc.selector, 'at_least(:once)') if node.parent.children[1] != :times
          elsif verb == :returns
            @source_rewriter.replace(node.loc.selector, 'and_return')
          elsif verb == :times
            if action&.int_type?
              times = action.children[0]
              if times == 1
                @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), '.once')
              elsif times == 2
                @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), '.twice')
              end
            elsif action&.send_type? && action&.children[1] == :any_times
              @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_least(:once)')
            end
          elsif verb == :at_least && action.int_type?
            times = action.children[0]
            if times == 1
              @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_least(:once)')
            elsif times == 2
              @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_least(:twice)')
            else
              @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), ".at_least(#{times}).times")
            end
          elsif verb == :at_most && action.int_type?
            times = action.children[0]
            if times == 1
              @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_most(:once)')
            elsif times == 2
              @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), '.at_most(:twice)')
            else
              @source_rewriter.replace(range(target.loc.expression.end_pos, node.loc.expression.end_pos), ".at_most(#{times}).times")
            end
          elsif verb == :is_a
            @source_rewriter.replace(node.loc.selector, 'kind_of')
          elsif verb == :numeric
            @source_rewriter.replace(node.loc.selector, 'kind_of(Numeric)')

          # RR::WildcardMatchers::HashIncluding => hash_including
          elsif verb == :new && target.const_type? && target.children.last == :HashIncluding
            range = range(target.loc.expression.begin_pos, node.loc.selector.end_pos)
            @source_rewriter.replace(range, 'hash_including')

          # RR::WildcardMatchers::Satisfy => rr_satsify
          elsif verb == :new && target.const_type? && target.children.last == :Satisfy
            range = range(target.loc.expression.begin_pos, node.loc.selector.end_pos)
            @source_rewriter.replace(range, 'rr_satisfy')

          # rr_satisfy => satisfy
          elsif verb == :rr_satisfy
            @source_rewriter.replace(node.loc.selector, 'satisfy')

          # RR.reset => removed
          elsif verb == :reset && target.const_type? && target.children.last == :RR
            sibling = node.root? ? nil : node.parent.children[node.sibling_index + 1]
            end_pos = sibling ? sibling.loc.expression.begin_pos : node.loc.expression.end_pos
            @source_rewriter.remove(range(node.loc.expression.begin_pos, end_pos))

          # any_instance_of(klass, method: return) => allow_any_instance_of
          # any_instance_of(klass) { block } => allow_any_instance_of / expect_any_instance_of
          elsif verb == :any_instance_of
            class_name = action.loc.expression.source
            if !args.empty?
              stubs = []
              indent = line_indent(node)
              node.each_node(:pair) do |pair|
                method_name = pair.children.first.loc.expression.source.sub(/^:/,'')
                method_result = pair.children.last.loc.expression.source
                stubs << "allow_any_instance_of(#{class_name}).to receive(:#{method_name}).and_return(#{method_result})"
              end

              @source_rewriter.replace(node.loc.expression, stubs.join("\n#{indent}"))
            else # parent is a block type
              begin_node = node.parent.children.last
              begin_node.each_node(:send) do |send_node|
                stub_method = send_node.children[1]
                receive_method = send_node.parent.children[1]
                has_args = !send_node.parent.children[2].nil?
                next unless [:stub, :mock].include?(stub_method)

                expectation = remove_never_node(send_node) ? 'not_to' : 'to'
                expect_method = stub_method == :stub ? 'allow' : 'expect'
                @source_rewriter.replace(range(send_node.parent.loc.expression.begin_pos, send_node.parent.loc.selector.end_pos), "#{expect_method}_any_instance_of(#{class_name}).#{expectation} receive(:#{receive_method})#{has_args ? '.with' : ''}")
              end
              # Remove the any_instance_of
              # If it's a begin block, we have to go a level deeper
              first_statement = begin_node.begin_type? ? begin_node.children.first : begin_node
              last_statement = begin_node.begin_type? ? begin_node.children.last : begin_node
              @source_rewriter.remove(range(node.loc.expression.begin_pos, first_statement.loc.expression.begin_pos)) # start of block
              @source_rewriter.remove(range(last_statement.loc.expression.end_pos, node.parent.loc.expression.end_pos)) # end of block
            end

          # mock => expect().to receive
          elsif verb == :mock
            next if node.each_ancestor(:block).find { |n| n.children[0].children[1] == :any_instance_of }
            if action.nil?
              @source_rewriter.replace(node.loc.selector, 'double')
            else
              expectation = remove_never_node(node) ? 'not_to' : 'to'

              @source_rewriter.replace(node.loc.selector, 'expect')
              method_name = node.parent.loc.selector.source
              has_args = !node.parent.children[2].nil?
              @source_rewriter.replace(node.parent.loc.selector, "#{expectation} receive(:#{method_name})#{has_args ? '.with' : ''}")
            end

          # stub => allow().to receive and double
          elsif verb == :stub
            next if node.each_ancestor(:block).find { |n| n.children[0].children[1] == :any_instance_of }
            if action.nil?
              @source_rewriter.replace(node.loc.selector, 'double')
            else
              @source_rewriter.replace(node.loc.selector, 'allow')
              if node.parent.send_type?
                method_name = node.parent.loc.selector.source
                has_args = !node.parent.children[2].nil?
                @source_rewriter.replace(node.parent.loc.selector, "to receive(:#{method_name})#{has_args ? '.with' : ''}")
              else
                # Stubbing a method on Kernel
                method_name = node.children[2].children[1]
                @source_rewriter.replace(node.loc.expression, "allow(Kernel).to receive(:#{method_name})")
              end
            end

          # dont_allow => expect().not_to receive
          elsif verb == :dont_allow
            @source_rewriter.replace(node.loc.selector, 'expect')
            if args.empty?
              method_name = node.parent.loc.selector.source
              has_args = !node.parent.children[2].nil?
              @source_rewriter.replace(node.parent.loc.selector, "not_to receive(:#{method_name})#{has_args ? '.with' : ''}")
            else
              # dont_allow(object, :method) syntax
              method_name = args.first.children[0]
              @source_rewriter.replace(range(action.loc.expression.end_pos, node.loc.expression.end_pos), ").not_to receive(:#{method_name})")
            end
          end
        end

        @source_rewriter.process
      end

      private

      def range(start_pos, end_pos)
        Parser::Source::Range.new(@source_buffer, start_pos, end_pos)
      end

      # Find any never or times(0) methods chained in the expression and remove them.
      # Return true if a node was found and removed, false otherwise.
      def remove_never_node(node)
        if never_node = node.each_ancestor(:send).find { |n| n.children[1] == :never }
          @source_rewriter.remove(range(never_node.children.first.loc.expression.end_pos, never_node.loc.selector.end_pos))
          return true
        elsif times_zero_node = node.each_ancestor(:send).find { |n| n.children[1] == :times && n.children[2].int_type? && n.children[2].children[0] == 0 }
          @source_rewriter.remove(range(times_zero_node.children[0].loc.expression.end_pos, times_zero_node.loc.expression.end_pos))
          return true
        end
        false
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
