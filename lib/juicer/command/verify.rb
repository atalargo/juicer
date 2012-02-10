require "juicer/command/util"
require "rubygems"
require "cmdparse"
require "pathname"

module Juicer
  module Command
    # Verifies problem-free-ness of source code (JavaScript and CSS)
    #
    class Verify < CmdParse::Command
      include Juicer::Command::Util

      # Initializes command
      #
      def initialize(log = nil)
        super('verify', false, true)
        @log = log || Logger.new($STDIO)
        self.short_desc = "Verifies that the given JavaScript/CSS file is problem free"
        self.description = <<-EOF
Uses JsLint (http://www.jslint.com) to check that code adheres to good coding
practices to avoid potential bugs, and protect against introducing bugs by
minifying.
        EOF
      end

      # Execute command
      #
      def execute(args)
        # Need atleast one file
        raise ArgumentError.new('Please provide atleast one input file/pattern') if args.length == 0
        Juicer::Command::Verify.check_all(files(args), @log)
      end

      def self.check_all(files, log = nil, worker_number = 1)
        log ||= Logger.new($stdio)
        jslint = Juicer::JsLint.new(:bin_path => Juicer.home)
        problems = false

        # Check that JsLint is installed
        raise FileNotFoundError.new("Missing 3rd party library JsLint, install with\njuicer install jslint") if jslint.locate_lib.nil?

#         p "CHECK ALL"
        # Verify all files
        current_nb_worker = 0
        mut = Mutex.new
        Thread.abort_on_exception = true
#         p "max worker #{worker_number}"
        files.each do |file|
            Thread.new do
#                 mut.synchronize{
                    current_nb_worker += 1
#                 }
#                 p "Thread #{current_nb_worker}"
                report = jslint.check(file)


                if report.ok?
                    log.info "Verifying #{file} with JsLint  OK!"
                else
                    problems = true
                    log.info "Verifying #{file} with JsLint "
                    log.warn "  Problems detected on #{file}"
                    log.warn "  #{report.errors.join("\n").gsub(/\n/, "\n  ")}\n"
                end
#                 mut.synchronize{
                    current_nb_worker -= 1
#             }
            end
#             t.join
#             p "c #{current_nb_worker} m #{worker_number} (#{worker_number.inspect}) v #{current_nb_worker == worker_number} t #{Thread.list.count}"
            while current_nb_worker == worker_number
                sleep(0.1)
            end
        end

        while current_nb_worker > 0
            sleep(0.1)
#             p "current Thread #{current_nb_worker}"
        end
#         exit 1
        !problems
      end
    end
  end
end
