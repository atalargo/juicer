require "juicer/chainable"

# Merge several files into one single output file
module Juicer
  module Merger
    class Base
      include Chainable
      attr_accessor :dependency_resolver
      attr_reader :files

      def initialize(files = [], options = {})
        @files = []
        @root = nil
        @options = options
        @dependency_resolver ||= nil
        @worker_number = (options[:worker].nil? ? 1 : options[:worker])
        self.append files
      end

      #
      # Append contents to output. Resolves dependencies and adds
      # required files recursively
      # file = A file to add to merged content
      #
      def append(file)
        return file.each { |f| self << f } if file.class == Array
        return if @files.include?(file)

        if !@dependency_resolver.nil?
          path = File.expand_path(file)
          resolve_dependencies(path)
        elsif !@files.include?(file)
          @files << file
        end
      end

      alias_method :<<, :append

      #
      # Save the merged contents. If a filename is given the new file is
      # written. If a stream is provided, contents are written to it.
      #
      def save(file_or_stream)
        output = file_or_stream

        output_f = nil
        if output.is_a? String
            @root = Pathname.new(File.dirname(File.expand_path(output)))
            output_f = File.open(output, 'w')
        elsif !output.is_a? Array
            @root = Pathname.new(File.expand_path("."))
            output_f = output
        end

        if output.is_a?(Array)
            mut = Mutex.new
            current_nb_worker = 0
            @files.each_with_index do |f,i|
                Thread.new do
                    mut.synchronize{current_nb_worker += 1}
                    begin
                        File.open(output[i], 'w') do |output_f|
                            output_f.puts(merge(@files[i]))
                        end
                    ensure
                        mut.synchronize{current_nb_worker -= 1}
                    end
                end
                while current_nb_worker == @worker_number
                    sleep(0.01)
                end
            end
            while current_nb_worker > 0
                sleep(0.01)
            end
        else
            @files.each do |f|
                output_f.puts(merge(f))
            end
            output_f.close if file_or_stream.is_a? String
        end
      end

      chain_method :save

     private
      def resolve_dependencies(file)
        @files.concat @dependency_resolver.resolve(file)
        @files.uniq!
      end

      # Fetch contents of a single file. May be overridden in subclasses to provide
      # custom content filtering
      def merge(file)
        IO.read(file) + "\n"
      end
    end
  end
end
