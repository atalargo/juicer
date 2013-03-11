#!/usr/bin/env ruby
require 'tempfile'
require 'juicer-ice/minifyer/java_base'
require 'juicer-ice/chainable'

require 'monitor'
require 'thread'
module Juicer
  module Minifyer

    # Provides an interface to the YUI compressor library using
    # Juicer::Shell::Binary. The YUI compressor library is implemented
    # using Java, and as such Java is required when running this code. Also, the
    # YUI jar file has to be provided.
    #
    # The YUI Compressor is invoked using the java binary and the YUI Compressor
    # jar file.
    #
    # Providing the Jar file (usually yuicompressor-x.y.z.jar) can be done in
    # several ways. The following directories are searched (in preferred order)
    #
    #  1. The directory specified by the option :bin_path
    #  2. The directory specified by the environment variable $YUIC_HOME, if set
    #  3. Current working directory
    #
    # For more information on how the Jar is located, see
    # +Juicer::Minify::YuiCompressor.locate_jar+
    #
    # Author::    Christian Johansen (christian@cjohansen.no)
    # Copyright:: Copyright (c) 2008-2009 Christian Johansen
    # License::   MIT
    #
    # = Usage example =
    # yuic = Juicer::Minifyer::YuiCompressor.new
    # yuic.java = "/usr/local/bin/java" # If 'java' is not on path
    # yuic.path << "/home/user/java/yui_compressor/"
    # yuic.save("", "")
    #
    #
    class YuiCompressor
      include Juicer::Minifyer::JavaBase
      include Juicer::Chainable

      # Compresses a file using the YUI Compressor. Note that the :bin_path
      # option needs to be set in order for YuiCompressor to find and use the
      # YUI jar file. Please refer to the class documentation for how to set
      # this.
      #
      # file = The file to compress
      # output = A file or stream to save the results to. If not provided the
      #          original file will be overwritten
      # type = Either :js or :css. If this parameter is not provided, the type
      #        is guessed from the suffix on the input file name
      def save(file, output = nil, type = nil)
        files = file
        files = [file] if files.is_a?(String)
        type = type.nil? ? files[0].split('.')[-1].to_sym : type

        Thread.abort_on_exception = true

#         mut = Mutex.new

        lo_jar = locate_jar


        current_nb_worker = 0
        threads = Array.new(@workers)
        work_queue = SizedQueue.new(@workers)
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

                    FileUtils.mkdir_p(File.dirname(currency[:output]))
                    result = execute(%Q{-jar "#{lo_jar}"#{jar_args} -o "#{currency[:output]}" "#{currency[:input]}"})

                    threads.synchronize do
                        threads_available.signal
                    end
                end

            end
        end

        producer_thread = Thread.new do
            files.each_pair do |fileo, filem|
                work_queue << {:output => fileo, :input => filem}
                threads.synchronize do
                    threads_available.signal
                end
            end
        end

        producer_thread.join

        threads.each do |thread|
            thread.join
        end

      end

      chain_method :save

      def self.bin_base_name
        "yuicompressor"
      end

      def self.env_name
        "YUIC_HOME"
      end

     private
      # Returns a map of options accepted by YUI Compressor, currently:
      #
      # :charset
      # :line_break
      # :no_munge (JavaScript only)
      # :preserve_semi
      # :disable_optimizations
      #
      # In addition, some class level options may be set:
      # :bin_path (defaults to Dir.cwd)
      # :java     (Java command, defaults to 'java')
      def default_options
        { :charset => nil, :line_break => nil, :nomunge => nil,
          :preserve_semi => nil, :disable_optimizations => nil }
      end
    end
  end
end
