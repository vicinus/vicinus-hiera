require File.expand_path('../parent_resource', __FILE__)

module Puppet::Util::Hiera
class Module
  attr_reader :name
  attr_reader :loaded
  alias :loaded? :loaded
  attr_reader :module_areas
  attr_reader :active_area
  attr_reader :parent_resource

  public
  def initialize(loader, name)
    @name = name
    @loaded = false
    @active_area = nil
  end

  def get_hiera_name()
    return "#{@name}::area_#{@active_area}" if @active_area
    return @name
  end

  def get_required_unloaded_modules()
    load_areas();
    required_module_names = load_required_module_names()
    required_module_names.concat(load_areas_required_module_names())
    result = []
    required_module_names.each do | module_name |
      moduleob = ModuleLoader.modules(module_name)
      result << moduleob if not moduleob.loaded?
    end
    return result
  end

  def load(start_anchor, end_anchor)
    @start_anchor = start_anchor
    @end_anchor = end_anchor
    load_areas();
    load_resources()
    load_areas_resources()
    @loaded = true
  end

  private
  def load_areas
    if not @module_areas
      @module_areas = ModuleLoader.hiera_lookup_array(ModuleLoader.hiera_areas_name, [])
    end
  end

  def load_class(name, params={})
    params ||= {}
    update_dependencies(params)
    debug("load class: #{name} " + params.inspect)
    ModuleLoader.load_class(name, params)
  end

  def load_classes(names=[], params={})
    names ||= []
    params ||= {}
    names.each do | name |
      load_class(name, params[name])
    end
  end

  def merge(left,right)
    ModuleLoader.merge_answer(left, right)
  end

  def debug(msg)
    ModuleLoader.debug(msg)
  end


  def store_update_resources(res={})
    ModuleLoader.add_update_resources(res)
  end

  def get_res_type_defaults(res_type, parent_resource)
    res_type_defaults = ModuleLoader.hiera_lookup_hash("#{ModuleLoader.hiera_defaults_name}::#{res_type}", {})
    if parent_resource
      debug("defaults before mapping: " + res_type_defaults.inspect)
      defaults_mapping = ModuleLoader.hiera_lookup_hash("#{ModuleLoader.hiera_default_mapping_name}::from_#{parent_resource.type()}_to_#{res_type}" , { 'ensure' => 'ensure' })
      debug("default mapping: " + defaults_mapping.inspect)
      parent_resource.update_defaults(res_type_defaults, defaults_mapping)
      debug("defaults after mapping: " + res_type_defaults.inspect)
    end
    res_type_defaults
  end

  def update_dependencies(params, parent_resource=nil)
    parent_resource.update_require(params) if parent_resource
    if params['before']
      params['before'] = [ params['before'] ] if not params['before'].is_a? Array
      params['before'] << @end_anchor
    else
      params['before'] = [ @end_anchor ]
    end
    if params['require']
      params['require'] = [ params['require'] ] if not params['require'].is_a? Array
      params['require'] << @start_anchor
    else
      params['require'] = [ @start_anchor ]
    end
  end

  def get_act_resource_name(name, parent_resource=nil)
    return name if not parent_resource
    return "#{parent_resource.get_parent_names()}_#{name}"
  end

  def deep_copy(ob)
    Marshal.load(Marshal.dump(ob))
  end

  def internal_load_resources(resources={}, parent_resource=nil)
    resources.each do | res_type, res_params |
      debug("res_type: #{res_type}")

      res_type_defaults = get_res_type_defaults(res_type, parent_resource)
      default_subresources = ModuleLoader.hiera_lookup_hash("#{ModuleLoader.hiera_default_subresources_name}::#{res_type}", {})
      res_params.each do | res_name, res_data |
        debug("res_name: #{res_name} (#{res_data.inspect})")
        subresources = res_data.delete(ModuleLoader.hiera_subresources_name) {{}}
        update_dependencies(res_data, parent_resource)
        ModuleLoader.create_resource(res_type, get_act_resource_name(res_name, parent_resource), res_data, res_type_defaults)
        next if default_subresources.empty? and subresources.empty?

        allsubresources = deep_copy(default_subresources)
        allsubresources.deep_merge!(subresources)
        debug("subresources: #{allsubresources.inspect} / #{default_subresources.inspect} / #{subresources.inspect}")

        act_res_data = deep_copy(res_type_defaults)
        act_res_data.deep_merge!(res_data)
        debug("parent data: #{act_res_data.inspect} / #{res_type_defaults.inspect} / #{res_data.inspect}")
        internal_load_resources(allsubresources, ParentResource.new(res_type, res_name, act_res_data, parent_resource))
      end
    end
  end

  def load_resources()
    resources = ModuleLoader.hiera_lookup_hash(ModuleLoader.hiera_resources_name, {})
    # 1. load classes:
    load_classes(resources.delete('class'), 
        resources.delete(ModuleLoader.hiera_class_params_name))

    # 3. remove resource updates:
    store_update_resources(resources.delete(ModuleLoader.hiera_update_resources_name))

    # 2. load the remaining non classes:
    internal_load_resources(resources)
  end

  def load_areas_resources()
    @module_areas.each do | area |
      @active_area = area
      load_resources()
      @active_area = nil
    end
  end

  def load_required_module_names()
    ModuleLoader.hiera_lookup_array(ModuleLoader.hiera_require_name, [])
  end

  def load_areas_required_module_names()
    result = []
    @module_areas.each do | area |
      @active_area = area
      result.concat(ModuleLoader.hiera_lookup_array(ModuleLoader.hiera_require_name, []))
      @active_area = nil
    end
    return result
  end
  
end
end
