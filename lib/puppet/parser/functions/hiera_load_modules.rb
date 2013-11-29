require File.expand_path('../../../util/hiera/module_loader', __FILE__)

module Puppet::Parser::Functions
  newfunction(:hiera_load_modules, :type => :rvalue) do |args|
    modules = {}
    modules = args[0] if args.length > 0

    Puppet::Util::Hiera::ModuleLoader.init(self, compiler)
    Puppet::Util::Hiera::ModuleLoader.load(modules)
  end
end
