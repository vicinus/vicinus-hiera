module Puppet::Util::Hiera
class ParentResource
  attr_reader :type
  attr_reader :name
  attr_reader :data
  attr_reader :parent

  def initialize(type, name, data, parent)
    @type = type
    @name = name
    data['title'] = name
    @data = data
    @parent = parent
  end

  def get_id()
    return "#{@type.capitalize}[#{@name}]"
  end

  def [](key)
    @data[key]
  end

  def get_parent_names
    if @parent === nil
      return @name
    else
      return "#{@parent.get_parent_names}_#{@name}"
    end
  end

  def update_require(res_data)
    if res_data['require']
      if res_data['require'].is_a?(Array)
        res_data['require'] << get_id()
      else
        res_data['require'] = [ res_data['require'], get_id() ]
      end
    else
      res_data['require'] = [ get_id() ]
    end
    ModuleLoader.debug("rd-require: #{res_data['require'].inspect}")
  end

  def update_defaults(defaults, defaults_mapping)
    defaults_mapping.each do | param, value |
      value = { value => nil } if not value.is_a?(Hash)
      value.each do | val, toreplaceval |
        if toreplaceval
          defaults[val] = toreplaceval.gsub(/([^&]?)&\{#{param}\}/, '\1' + @data[param]).gsub("&&", "&")
        else
          defaults[val] = @data[param]
        end
      end
    end
  end

end
end
