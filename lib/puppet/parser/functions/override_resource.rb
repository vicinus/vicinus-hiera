Puppet::Parser::Functions::newfunction(:override_resource, :arity => 3, :doc => <<-'ENDHEREDOC') do |args|
  ENDHEREDOC
  raise ArgumentError, ("override_resource(): wrong number of arguments (#{args.length}; must be 3)") if args.length > 3
  type, res_name, params = args
  Puppet.debug("override fun: #{type}[#{res_name}] (#{params.inspect})")

  source = self.source.clone
  source.meta_def(:child_of?) do |klass|
    true
  end
  res_params = params.collect { |name, value|
    par = Puppet::Parser::Resource::Param.new(
      :name   => name,
      :value  => value,
      :source => source
    )
  }

  Puppet.debug("override: #{type}[#{res_name}] - #{source.inspect}")
  res = Puppet::Parser::Resource.new(
    type, res_name,
    :parameters => res_params,
    :source => source,
    :scope => self
  )
  compiler.add_override(res)
end
