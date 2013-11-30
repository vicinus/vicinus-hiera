require 'hiera_puppet'
require File.expand_path('../scope', __FILE__)
require File.expand_path('../module', __FILE__)

begin
  require 'deep_merge'
rescue LoadError
end

module Puppet::Util::Hiera
class ModuleLoader
  class << self
    if defined? @@undef_new
      undef_method :new
      @@undef_new = 1
    end
    attr_reader :scope
    attr_reader :compiler
    attr_reader :hiera_scope

    attr_reader :hiera_areas_name
    attr_reader :hiera_require_name
    attr_reader :hiera_resources_name
    attr_reader :hiera_class_params_name
    attr_reader :hiera_update_resources_name
    attr_reader :hiera_defaults_name
    attr_reader :hiera_default_mapping_name
    attr_reader :hiera_subresources_name
    attr_reader :hiera_default_subresources_name

    def init(scope, compiler)
      @modules = {}
      @to_load_modules = []
      @scope = scope
      @compiler = compiler
      @hiera_scope = Scope.new(scope)

      @hiera_modules_name = function_hiera('hiera::modules_name', 'modules')
      @hiera_require_name = function_hiera('hiera::require_name', 'require')
      @hiera_areas_name = function_hiera('hiera::areas_name', 'areas')
      @hiera_stages_name = function_hiera('hiera::stages_name', 'stages')
      @hiera_resources_name = function_hiera('hiera::resources_name', 'resources')
      @hiera_subresources_name = function_hiera('hiera::subresources_name', 'subresources')
      @hiera_default_subresources_name = function_hiera('hiera::default_subresources_name', 'default_subresources')
      @hiera_defaults_name = function_hiera('hiera::defaults_name', 'defaults')
      @hiera_default_values_name = function_hiera('hiera::default_values_name', 'default_values')
      @hiera_class_params_name = function_hiera('hiera::class_params_name', 'class_params')
      @hiera_default_mapping_name = function_hiera('hiera::default_mapping_name', 'default_mapping')
      @hiera_update_resources_name = function_hiera('hiera::update_resources_name', 'update_resources')

      @toupdate_resources = {}
    end

    def function_hiera(key, default, override=nil, type=:priority)
      HieraPuppet.lookup(key, default, @hiera_scope, override, type)
    end

    public

    def merge_answer(left,right)
      case Hiera::Config[:merge_behavior]
      when :deeper,'deeper'
        left.deep_merge!(right)
      when :deep,'deep'
        left.deep_merge(right)
      else # Native and undefined
        left.merge(right)
      end
    end

    def add_update_resources(res)
      res ||= {}
      res.each do | key, value |
        if @toupdate_resources[key]
          @toupdate_resources[key].merge(value)
        else
          @toupdate_resources[key] = value
        end
      end
    end
 
    def update_resources()
      @toupdate_resources.each do | res_type, res_data |
        res_data.each do | res_name, res_params |
          if resource = @scope.findresource("#{res_type}[#{res_name}]")
            debug("update resource: #{res_type}[#{res_name}]");
            res_params.each do | param, value |
              resource[param] = value
            end
          else
            Puppet.warning("Couldn't find resource '#{res_type}[#{res_name}]' for update, so nothing done!")
          end
        end
      end
    end
 
    def hiera_lookup(lookup, default, override, type)
      HieraPuppet.lookup(@hiera_scope.get_hiera_lookup_name(lookup),
          default, @hiera_scope, override, type)
    end

    def hiera_lookup_array(lookup, default, override=nil)
      hiera_lookup(lookup, default, override, :array)
    end

    def hiera_lookup_hash(lookup, default, override=nil)
      hiera_lookup(lookup, default, override, :hash)
    end

    def load_class(name, params, lazy=false)
      classes = @compiler.evaluate_classes({name => params}, @scope, lazy)
      if classes.empty?
        # Throw an error if we didn't evaluate all of the classes.
        str = "Could not find class #{name}"

        if n = @scope.namespaces and ! n.empty? and n != [""]
          str += " in namespaces #{n.join(", ")}"
        end
        self.fail Puppet::ParseError, str
      end
    end

    def create_resource(res_type, res_name, res_data, res_defaults)
      debug("create_resource: #{res_type}[#{res_name}] (#{res_data.inspect}) / #{res_defaults.inspect}")
      @scope.function_create_resources([res_type, { res_name => res_data }, res_defaults])
    end

    def debug(msg)
      Puppet.debug("hiera_module() #{@hiera_scope.get_hiera_name()}: #{msg}")
    end

    def modules(name)
      return @modules[name] if @modules[name]
      @modules[name] = Module.new(self, name)
    end

    def load_modules(to_load_modules, start_anchor, end_anchor)
      to_load_modules.map!{|name| modules(name)}.reject!{|ob| ob.loaded?}
      while not to_load_modules.empty?
        moduleob = to_load_modules.shift
        next if moduleob.loaded?
        @hiera_scope.hiera_module = moduleob
        debug("Trying to load module: #{moduleob.name}")
        required = moduleob.get_required_unloaded_modules()
        if not required.empty?
          debug("Unmet required modules: #{required.map{|ob| ob.name}.inspect}, stoping loading #{moduleob.name}")
          @hiera_scope.hiera_module = nil
          to_load_modules.unshift(moduleob)
          to_load_modules.unshift(*required)
          next
        end
        moduleob.load(start_anchor, end_anchor)
        @hiera_scope.hiera_module = nil
      end
    end

    def create_anchor(name)
      debug("create_anchor: #{name}")
      @scope.function_create_resources(['anchor', { name => {} }])
      return "Anchor[#{name}]"
    end

    def get_stages(modulestoload={})
      hiera_lookup_array(@hiera_stages_name, ['default'])
    end

    def load_stage(name, start_anchor, modulestoload = [])
      modulestoload ||= []
      @hiera_scope.stage_name = name
      end_anchor = create_anchor("stage_#{name}_end")
      load_modules(modulestoload + hiera_lookup_array(@hiera_modules_name, []), start_anchor, end_anchor)
      @hiera_scope.stage_name = ''
      return end_anchor
    end

    def load(modulestoload={})
      start_anchor = create_anchor('start')
      get_stages().each do |stage|
        debug("Load stage: #{stage}.")
        start_anchor = load_stage(stage, start_anchor, modulestoload[stage])
      end
      update_resources()
      res = {}
      @modules.each do |k,v|
        res[k] = 1
      end
      debug("Loaded modules: #{res.inspect}")
      return res
    end

  end
end
end
