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
    attr_reader :hiera_defaults_name
    attr_reader :hiera_default_mapping_name
    attr_reader :hiera_subresources_name
    attr_reader :hiera_default_subresources_name
    attr_reader :hiera_collection_name

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
      @hiera_class_params_name = function_hiera('hiera::class_params_name', 'class_params')
      @hiera_default_mapping_name = function_hiera('hiera::default_mapping_name', 'default_mapping')
      @hiera_collection_name = function_hiera('hiera::collection_name', 'collection')
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

    def hiera_lookup(lookup, default, override, type, add_sub)
      if add_sub and type == :hash
        res = {}
        
        @hiera_scope.get_hiera_lookup_names(lookup).reverse.each do |l|
          data = HieraPuppet.lookup(l, default, @hiera_scope,
              override, type)
          debug("lookup parents #{l}: #{data.inspect}")
          merge_answer(res, data)
        end
        return res
      else
        HieraPuppet.lookup(@hiera_scope.get_hiera_lookup_name(lookup),
            default, @hiera_scope, override, type)
      end
    end



    def hiera_lookup_array(lookup, default, override=nil)
      hiera_lookup(lookup, default, override, :array, false)
    end

    def hiera_lookup_hash(lookup, default, add_sub=false, override=nil)
      hiera_lookup(lookup, default, override, :hash, add_sub)
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

    def override_resource(res_type, res_name, res_data)
      debug("override_resource: #{res_type}[#{res_name}] (#{res_data.inspect})")
      @scope.function_override_resource([res_type, res_name, res_data])
    end

    def realize_resources(query, res_type, type)
      case type
      when "exported"
        debug("realize_resources: #{res_type.split("::").collect { |s| s.capitalize }.join("::")} <<| #{query} |>>")
      when "virtual"
        debug("realize_resources: #{res_type.split("::").collect { |s| s.capitalize }.join("::")} <| #{query} |>")
      else
        debug("realize_resources: Unknown Collection query type #{type}")
      end
      @scope.function_realize_resources([query, res_type, type])
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
