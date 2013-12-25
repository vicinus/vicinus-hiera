# realize_resources("tag == testit", "user", "exported")
Puppet::Parser::Functions::newfunction(:realize_resources, :arity => 3, :doc => <<-'ENDHEREDOC') do |args|
  ENDHEREDOC
  raise ArgumentError, ("realize_resources(): wrong number of arguments (#{args.length}; must be 3)") if args.length > 3

  querystr, typename, form = args

  case form
  when "exported"
    querystr = "#{typename.split("::").collect { |s| s.capitalize }.join("::")} <<| #{querystr} |>>"
  when "virtual"
    querystr = "#{typename.split("::").collect { |s| s.capitalize }.join("::")} <| #{querystr} |>"
  else
    raise Puppet::Error.new("Unknown Collection query form #{form}")
  end

  begin
    parser = Puppet::Parser::ParserFactory.parser(self.environment)
    parser.string = querystr
    res = parser.parse
  rescue => detail
    Puppet.warning("Parse error: #{detail}")
  end
  Puppet.debug("Parse result: #{res.inspect}")
  Puppet.debug("Parse result code: #{res.code.inspect}")
  Puppet.debug("Parse result code query: #{res.code[0].query.inspect}")
  query = res.code[0].query
  match, code = query && query.safeevaluate(self)

  newcoll = Puppet::Parser::Collector.new(self, typename, match, code, form.to_sym)

  compiler.add_collection(newcoll)
end
