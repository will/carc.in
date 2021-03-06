require "ecr/macros"
require "tempfile"

require "./command"

class Carcin::Sandbox::BuildWrapperCommand
  class Wrapper
    getter path
    getter name
    getter timeout
    getter memory
    getter whitelist
    ecr_file "#{__DIR__}/wrapper.ecr"

    def initialize(@path, @name, @binary, @timeout, @memory, @whitelist)
    end

    def binary
      @binary || "/usr/bin/#{@name}"
    end
  end

  include Command

  def execute definition, version
    ensure_path_to definition

    wrapper = wrapper_path definition, version

    file = Tempfile.open("sandbox_wrapper") do |io|
      Wrapper.new(
        path_to(definition, version),
        definition.name,
        definition.binary,
        definition.timeout,
        definition.memory,
        whitelist_path(definition, version)
      ).to_s(io)
    end

    unless system %(crystal build --release -o "#{wrapper}" "#{file.path}")
      abort "Failed to build #{wrapper}"
    end

    file.delete

    system %(chmod 4755 "#{wrapper}")
  end
end
