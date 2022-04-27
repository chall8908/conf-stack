# frozen_string_literal: true

require 'set'
require_relative "master_plan/version"

##
# Main configuration object.  Walks up the file tree looking for masterplan
# files and loading them to build a the configuration.
#
# These masterplan files are loaded starting from the current working directory
# and traversing up until a masterplan with a `at_project_root` directive or
# or the directory specified by a `project_root` directive is reached.
#
# Configuration options set with `configure` are latched once set to something
# non-nil.  This, along with the aforementioned load order of masterplan files,
# means that masterplan files closest to the source of your invokation will
# "beat" other masterplan files.
#
# A global masterplan located at $HOME/.masterplan (or equivalent) is loaded
# _last_.  You can use this to specify plans you want accessible everywhere
# or global configuration that should apply everywhere (unless overridden by
# more proximal masterplans).
#
# Additionally, there is a directive (`see_other`) that allows for masterplan
# files outside of the lookup tree to be loaded.
#
# See {DSL} for a full list of the commands provided by MasterPlan and a sample
# masterplan file.
class MasterPlan
  class Error < StandardError; end

  class MissingConfigurationError < Error
    def initialize(attribute)
      super "#{attribute} has not been defined.  Call `configure :#{attribute}[, value]` in a `#{MasterPlan::PLANFILE}` to set it."
    end
  end

  # Filename of masterplan files
  PLANFILE = '.masterplan'

  # Path to the top-level masterplan
  MASTER_PLAN = File.join(Dir.home, PLANFILE)

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
  # This directory is where Mastermind will stop looking for more
  # masterplans, so it's important that it be set.
  add_attribute :project_root

  def initialize
    @loaded_masterplans = Set.new

    lookup_and_load_masterplans
    load_masterplan MASTER_PLAN
  end

  # Loads a masterplan using the DSL, if it exists and hasn't been loaded already
  #
  # @param filename [String] the path to the masterplan to load
  # @return [Void]
  def load_masterplan filename
    if File.exists? filename and !@loaded_masterplans.include? filename
      @loaded_masterplans << filename
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
    return false if symbol.to_s.ends_with? '?'

    super
  rescue NoMethodError
    raise MissingConfigurationError, symbol
  end

  # Walks up the file tree looking for masterplans.
  #
  # @return [Void]
  def lookup_and_load_masterplans
    load_masterplan File.join(Dir.pwd, PLANFILE)

    # Walk up the tree until we reach the project root, the home directory, or
    # the root directory
    unless [project_root, Dir.home, '/'].include? Dir.pwd
      Dir.chdir('..') { lookup_and_load_masterplans }
    end
  end

  # Describes the DSL used in masterplan files.
  #
  # See the .masterplan file in the root of this repo for a full example of
  # the available options.
  class DSL
    # @param config [MasterPlan] the configuration object used by the DSL
    # @param filename [String] the path to the masterplan to be loaded
    def initialize(config, filename)
      @config = config
      @filename = filename
      instance_eval(File.read(filename), filename, 0) if File.exists? filename
    end

    # Specifies that another masterplan should also be loaded when loading
    # this masterplan.  NOTE: This _immediately_ loads the other masterplan.
    #
    # @param filename [String] the path to the masterplan to be loaded
    def see_also(filename)
      @config.load_masterplan(File.expand_path(filename))
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
    # masterplan resides in the root of the project.
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

      MasterPlan.add_attribute(attribute)
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
