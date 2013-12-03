module Puppet::Parser::Functions
  newfunction(:add_to_scope, :doc => <<-'ENDHEREDOC') do |args|
    Expects an hash as argument. Add each key value pair to the actual scope.

    Primary used for hiera < v1.3, because hiera only with version 1.3 supports
    references to hiera values, prior to v1.3 only references to variables in
    the global puppet scope were possible. With this function, it is possible
    to load values in the global scope, if called in the manifests/site.pp:

    add_to_scope(hiera_hash('hiera::globalconfig', 
      { puppettyp => 'agent', 'monitoring' => 'nrpe' }))
    ENDHEREDOC

    raise(Puppet::ParseError, "add_to_scope(): Wrong number of arguments "+
      "given (#{args.size} for 1)") if args.size != 1

    hash = args[0]
    raise(Puppet::ParseError, 
      'add_to_scope(): Requires hash as argument.') unless hash.is_a?(Hash)

    hash.each do | key, val |
      debug("adding to scope #{key}: #{val}")
      self.setvar(key, val)
    end
  end
end
