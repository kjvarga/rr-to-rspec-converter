require 'text_transformer'
require 'text_transformer_options'
require 'version'
require 'optparse'

module Rails5
  module SpecConverter
    class CLI
      def initialize
        @options = TextTransformerOptions.new
        OptionParser.new do |opts|
          opts.banner = "Usage: rr-to-rspec-converter [options] [files]"

          opts.on("--version", "Print version number") do |q|
            puts Rails5::SpecConverter::VERSION
            exit
          end

          opts.on("-q", "--quiet", "Run quietly") do |q|
            @options.quiet = q
          end
        end.parse!

        @files = ARGV
      end

      def run
        paths = @files.length > 0 ? @files : ["spec/**/*.rb", "test/**/*.rb"]

        paths.each do |path|
          Dir.glob(path) do |file_path|
            log "Processing: #{file_path}"

            original_content = File.read(file_path)
            @options.file_path = file_path
            transformed_content = Rails5::SpecConverter::TextTransformer.new(original_content, @options).transform
            File.write(file_path, transformed_content)
          rescue Errno::EISDIR
          end
        end
      end

      def log(str)
        return if @options.quiet?

        puts str
      end
    end
  end
end
