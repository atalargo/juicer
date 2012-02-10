#!/usr/bin/env ruby
require 'tempfile'
require 'juicer/minifyer/java_base'
require 'juicer/chainable'

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

        mut = Mutex.new

        files.each_with_index do |file,i|
            while @current_worker == @workers
                sleep(0.1)
            end
            Thread.new do
                begin
                    mut.synchronize{ @current_worker += 1 }
    #                 output ||= file
    #                 use_tmp = !output.is_a?(String)
    #                 output = File.join(Dir::tmpdir, File.basename(file) + '.min.tmp.' + type.to_s) if use_tmp

                    out = output[i]
                    FileUtils.mkdir_p(File.dirname(output[i]))

                    result = execute(%Q{-jar "#{locate_jar}"#{jar_args} -o "#{output[i]}" "#{files[i]}"})

#                     if use_tmp                            # If no output file is provided, YUI compressor will
#                         out.puts IO.read(out)         # compress to a temp file. This file should be cleared
#                         File.delete(out)                 # out after we fetch its contents.
#                     end
                    mut.synchronize{@current_worker -= 1}
                rescue => e
                    "Error on #{files[i]}"
                    mut.synchronize{@current_worker -= 1}
                    throw e
                end
            end
        end

        while @current_worker > 0
            sleep(0.1)
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
