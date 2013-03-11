require "juicer-ice/chainable"
require 'monitor'
require 'thread'

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

        if output.is_a?(Hash)
            @root = Pathname.new(File.expand_path("."))
            output_f = output

            current_nb_worker = 0
            threads = Array.new(@worker_number)
            work_queue = SizedQueue.new(@worker_number)
            threads.extend(MonitorMixin)
            threads_available = threads.new_cond

            consumerThread = Thread.new do
                loop do
                    found_index = nil

                    threads.synchronize do
                        threads_available.wait_while do
                            threads.select { |thread| thread.nil? || thread.status == false || thread['finished'].nil? == false}.length == 0
                        end
                        found_index = threads.index { |thread| thread.nil? || thread.status == false || thread["finished"].nil? == false }
                    end

                    currency = work_queue.pop

                    threads[found_index] = Thread.new(currency) do

                        File.open(output[currency], 'w') do |output_f|
                                output_f.puts(merge(currency))
                        end

                        Thread.current["finished"] = true

                        threads.synchronize do
                            threads_available.signal
                        end
                    end

                end
            end

            producer_thread = Thread.new do
                @files.each do |f|
                    work_queue << f
                    threads.synchronize do
                        threads_available.signal
                    end
                end
            end

            producer_thread.join

            threads.each do |thread|
                thread.join
            end
        else
            @root = Pathname.new(File.dirname(File.expand_path(output)))
            output_f = File.open(output, 'w')
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
