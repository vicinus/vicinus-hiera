module Puppet::Util::Hiera
class Scope
  HIERA_MODULE_NAME = "::hiera_module"
  attr_reader :real
  attr_accessor :hiera_module
  attr_writer :stage_name

  def initialize(real)
      @real = real
      @stage_name = ''
  end

  def get_hiera_module_name
    @hiera_module.name
  end

  def get_hiera_name
    res = ''
    res += @stage_name if @stage_name != 'default'
    if @hiera_module
      res += '::' if res != ''
      res += @hiera_module.get_hiera_name()
    end
    return res
  end

  def get_hiera_lookup_name(lookup)
    if @hiera_module
      "#{get_hiera_name()}::#{lookup}"
    else
      lookup
    end
  end

  def [](key)
    if key == HIERA_MODULE_NAME and @hiera_module
      ans = get_hiera_module_name()
    else
      ans = @real.lookupvar(key)
    end

    if ans.nil? or ans == ""
      nil
    else
      ans
    end
  end

  def include?(key)
    if key == HIERA_MODULE_NAME and @hiera_module
      true
    else
      @real.lookupvar(key) != ""
    end
  end

  def lookupvar(key)
    if key == HIERA_MODULE_NAME and @hiera_module
      get_hiera_module_name()
    else
      @real.lookupvar(key)
    end
  end

  def catalog
    @real.catalog
  end

  def resource
    @real.resource
  end

  def compiler
    @real.compiler
  end
end
end
