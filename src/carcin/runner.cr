require "./core_ext/process"

module Carcin
  module Runner
    RUNNERS = {} of String => Runner

    def self.execute request
      runner = RUNNERS[request.language]?
      if runner
        runner.execute request
      else
        Run.failed_for request, "unsupported language"
      end
    end

    def self.register language, klass
      RUNNERS[language] = klass
    end

    def capture executable, params
      Process.run executable, params, output: true, stderr: true
    end

    abstract def execute request
    abstract def versions
    abstract def short_name

    module StandardRunner
      include Runner

      abstract def wrapper_arguments request

      def name
        @name ||= self.class.name.downcase.split("::").last
      end

      def sandbox_basepath
        @sandbox_basepath ||= File.join Carcin::SANDBOX_BASEPATH, name
      end

      def versions
        @versions ||= Dir["#{sandbox_basepath}/*/"].map {|path| File.basename(path) }.sort.reverse
      end

      def execute request
        return Run.failed_for request, "no version available" if versions.empty?

        version = request.version || versions.first
        request.version = version
        if versions.includes? version
          status = run request, version
          Run.new request, status
        else
          Run.failed_for request, "unsupported version"
        end
      end

      protected def run request, version
        capture executable_for(version), wrapper_arguments(request)
      end

      protected def executable_for version
        File.join sandbox_basepath, "sandboxed_#{name}#{version}"
      end
    end

    class Crystal
      include StandardRunner

      def short_name
        "cr"
      end

      def wrapper_arguments request
        ["eval", request.code]
      end
    end
    register "crystal", Crystal.new

    class Ruby
      include StandardRunner

      def short_name
        "rb"
      end

      def wrapper_arguments request
        ["-e", request.code]
      end
    end
    register "ruby", Ruby.new

    class Gcc
      include StandardRunner

      def short_name
        "c"
      end

      def run request, version
        Process.run executable_for(version), nil, output: true, stderr: true, input: request.code
      end

      def wrapper_arguments request
      end
    end
    register "gcc", Gcc.new
  end
end
