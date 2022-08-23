# frozen_string_literal: true

require 'set'
require_relative "conf_stack/version"

##
# Main configuration object.  Walks up the file tree looking for configuration
# files and loading them to build a the configuration.
#
# These configuarion files are loaded starting from the current working directory
# and traversing up until a file with a `at_project_root` directive or the directory
# specified by a `project_root` directive is reached.
#
# Configuration options set with `configure` are latched once set to something
# non-nil.  This, along with the aforementioned load order of configuration files,
# means that configuration files closest to the source of your invokation will
# "beat" other configuration files.
#
# A global configuration located at $HOME/.confstack is loaded _last_.  You can
# use this to specify plans you want accessible everywhere or global configuration
# that should apply everywhere (unless overridden by more proximal files).
#
# Additionally, there is a directive (`see_other`) that allows for configuration
# files outside of the lookup tree to be loaded.
#
# See {DSL} for a full list of the commands provided by ConfStack.
class ConfStack
  class Error < StandardError; end

  class MissingConfigurationError < Error
    def initialize(attribute, filename)
      super "#{attribute} has not been defined.  Call `configure :#{attribute}[, value]` in a `#{filename}` to set it."
    end
  end

  class InvalidDirectoryError < Error
    def initialize(message, directory)
      super "#{message}:  #{directory} does not exist or is not a directory"
    end
  end

  # Adds an arbitrary attribute given by +attribute+ to the configuration class
  #
  # @param attribute [String,Symbol] the attribute to define
  #
  # @!macro [attach] add_attribute
  #   @!attribute [rw] $1
  def self.add_attribute(attribute)
    return if self.method_defined? attribute

    define_method "#{attribute}=" do |new_value=nil, &block|
      self.instance_variable_set("@#{attribute}", new_value.nil? ? block : new_value) if self.instance_variable_get("@#{attribute}").nil?
    end

    define_method attribute do
      value = self.instance_variable_get("@#{attribute}")
      return value unless value.respond_to?(:call)

      # Cache the value returned by the block so we're not doing potentially
      # expensive operations mutliple times.
      self.instance_variable_set("@#{attribute}", self.instance_eval(&value))
    end

    define_method "#{attribute}?" do
      true
    end

    nil
  end

  # Specifies the directory that is the root of your project.
  # This directory is where ConfStack will stop looking for more
  # files, so it's important that it be set.
  add_attribute :project_root

  # @param filename [String] the filename to look for to build configuration
  def initialize(filename: '.confstack')
    @filename = filename
    @loaded_conf_files = Set.new

    lookup_and_load_configuration_files
    load_configuration_file File.join(Dir.home, @filename)
  end

  # Loads a config file using the DSL, if it exists and hasn't been loaded already
  #
  # @param filename [String] the path to the config file to load
  # @return [Void]
  def load_configuration_file filename
    if File.exists? filename and !@loaded_conf_files.include? filename
      @loaded_conf_files << filename
      DSL.new(self, filename)
    end

    nil
  end

  private

  # Override the default NoMethodError with a more useful MissingConfigurationError.
  #
  # I
  #
  # Since the configuration object is used directly by plans for configuration information,
  # accessing non-existant configuration can lead to unhelpful NoMethodErrors.  This replaces
  # those errors with more helpful errors.
  def method_missing(symbol, *args)
    return false if symbol.to_s.end_with? '?'

    super
  rescue NoMethodError
    raise MissingConfigurationError.new(symbol, @filename)
  end

  def respond_to_missing?(symbol, include_private = false)
    symbol.to_s.end_with? '?' || super
  end

  # Walks up the file tree looking for configuration files.
  #
  # @return [Void]
  def lookup_and_load_configuration_files
    load_configuration_file File.join(Dir.pwd, @filename)

    # Walk up the tree until we reach the project root, the home directory, or
    # the root directory
    unless [project_root, Dir.home, '/'].include? Dir.pwd
      Dir.chdir('..') { lookup_and_load_configuration_files }
    end
  end

  # Describes the DSL used in configuration files.
  class DSL
    # @param config [ConfStack] the configuration object used by the DSL
    # @param filename [String] the path to the configuration file to be loaded
    def initialize(config, filename)
      @config = config
      @filename = filename
      instance_eval(File.read(filename), filename, 0) if File.exists? filename
    end

    # Specifies that another file should also be loaded when loading
    # this file.  NOTE: This _immediately_ loads the other file.
    #
    # @param filename [String] the path to the file to be loaded
    def see_also(filename)
      @config.load_configuration_file(File.expand_path(filename))
    end

    # Specifies the root of the project.
    # +root+ must be a directory.
    #
    # @param root [String] the root directory of the project
    # @raise [InvalidDirectoryError] if +root+ is not a directory
    def project_root(root)
      unless Dir.exist? root
        raise InvalidDirectoryError.new('Invalid project root', root)
      end

      @config.project_root = root
    end

    # Syntactic sugar on top of `project_root` to specify that the current
    # file resides in the root of the project.
    #
    # @see project_root
    def at_project_root
      project_root File.dirname(@filename)
    end

    # Add arbitrary configuration attributes to the configuration object.
    # Use this to add plan specific configuration options.
    #
    # @overload configure(attribute, value=nil, &block)
    #   @example configure(:foo, 'bar')
    #   @example configure(:foo) { 'bar' }
    #   @param attribute [String,Symbol] the attribute to define
    #   @param value [] the value to assign
    #   @param block [#call,nil] a callable that will return the value
    #
    # @overload configure(attribute)
    #   @example configure(foo: 'bar')
    #   @example configure('foo' => -> { 'bar' } # not recommended, but should work
    #   @param attribute [Hash] a single entry hash with the key as the attribute
    #     name and value as the corresponding value
    def configure(attribute, value=nil, &block)
      attribute, value = attribute.first if attribute.is_a? Hash

      ConfStack.add_attribute(attribute)
      @config.public_send "#{attribute}=", value, &block
    end
    alias_method :set, :configure

    # The following methods are maintained for backwards compatability with
    # .masterplan files used by Mastermind
    def backward_compatability(*args, **kwargs)
    end
    alias_method :plan_files, :backward_compatability
    alias_method :has_plan_files, :backward_compatability
    alias_method :plan_file, :backward_compatability
    alias_method :define_alias, :backward_compatability
    alias_method :skip_confirmation, :backward_compatability
  end
end
