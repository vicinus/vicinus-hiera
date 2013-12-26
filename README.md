hiera
=====

Alternative puppet hiera connector. Design goals:

 - Complete configuration in hiera
   * Only one default node in puppet manifest
   * Configuration of classes and resources
   * Support for deeper merging of class arguments

Configuration are structured via "hiera modules".

Hiera modules are absolute independent from puppet modules. Often there is a one to one relationship between a hiera module a puppet module because the hiera module is used to configure the puppet module. But hiera modules without a corresponding puppet module or multiple hiera modules for one puppet module are also common. For example we have a mysqlserver hiera module and a mysqlclient hiera module which both configure the mysql puppet module.

### Hiera lookups
Hiera lookups take the following form:
```
[modulename::[modulearea::]]type[::option]
```

At the moment the following hiera lookup types are defined:

  - require
  - resources
  - defaults
  - default_subresources
  - default_mapping
  - collection

### Term definition

The term _resource_ is used for all kind of resources, including classes.

In all examples the yaml backend is used for easy readability. But all other hiera backends also work. As long as they support deeper merging.

The merge behavior deeper is used. 


## Main Feature "Hiera Modules":

Hiera modules are used to load all needed resources for a note.

Default loading procedure of resources:

1. Determine which hiera modules should be loaded, by calling hiera_array('modules') and store them in unloadedmodules
2. Try to load the first hiera module in unloadedmodules
3. Set ::hiera_module to loading hiera module name
4. Check if loading hiera module requires other unloaded hiera modules, by calling hiera_array("#{module.name}::require") and filter already loaded hiera modules
5. If at least one unloaded module is required, prepend the unloaded hiera modules to unloadedmodules, unset ::hiera_module goto 1
6. Load resources by calling hiera_hash("#{module.name}::resources")
7. If resource class exists, load classes in order of definition with class_params
8. For each resource type load the defined resources
9. Mark hiera module loaded, unset ::hiera_module, goto 2

### Example:

hiera hierachy:
  - node/%{::clientcert}
  - role/%{::role}
  - modules/%{::hiera_module}
  - global

default node configuration:

```puppet
# if an enc is used, role can be provided by the enc:
$role = hiera_function('role', 'unknownrole')

node default {
  $modules = load_hiera_modules()
}
```

yaml configuration files:

_node/web01.example.com.yaml_
```yaml
role: webserver
```

_role/webserver.yaml_
```yaml
modules:
  - standard
  - webserver
  - apache

apache::resources:
  class_params:
    'apache':
      keepalive: false
      serveradmin: 'hostmaster@example.com'
  apache::vhosts:
    'www.example.com'
      servername: 'www.example.com'
      docroot: '/var/www/exmaple.com'
 
webserver::resources:
  file:
    'motd':
      path: '/etc/motd'
      content: "I'm a webserver." 
```

_modules/standard.yaml_
```yaml
require:
  - ntp
  [...]
```

_modules/ntp.yaml_
```yaml
ntp::resources:
  class:
    - ntp
  class_params:
    'ntp':
      servers:
        - 'ntp1.example.com iburst'
        - 'ntp2.example.com iburst'
```

_modules/apache.yaml_
```yaml
apache::resources:
  class:
    - apache
  class_params:
    'apache'
      purge_configs: true
      default_vhost: false
      serveradmin: 'webmaster@example.com'
      mpm_module: 'prefork'
```

## Feature: Virtual and Exported resources

Virtual and exported resources can be defined as in puppet. Prefix one @ for virtual resources and two @@ for exported resources to the resource type.

Realizing the virtual and exported resources is done by collections as in puppet described later.

### Example

Define a virtual user:

_modules/users.yaml_
```yaml
users::resources:
  @user:
    'luke':
      uid: 1000
```

Define to export sshkey resource:

_modules/standard.yaml_
```yaml
standard::resources:
  @@sshkey:
    %{::fqdn}:
      type: 'ssh-rsa'
      key: %{::sshrsakey}
```

## Feature: Hiera Module Areas

Areas work like case statements, loading resources only if the case matches. Every hiera module can define as many areas as they wish. The defined areas of one hiera module are complete independent of areas of other hiera modules.

### Example

Extending the apache hiera module with two areas:

1. osf_%{::osfamily} for some os specific resources
2. monitoring_%{::monitoring} for some resources depending on the used monitoring system

_modules/apache.yaml_
```yaml
apache::areas:
  - 'osf_%{::osfamily}'
  - 'monitoring_%{::monitoring}'

apache::resources:
  class:
    - apache
  class_params:
    'apache'
      purge_configs: true
      default_vhost: false
      serveradmin: 'webmaster@example.com'
      mpm_module: 'prefork'

apache::area_osf_Debian::resources:
  file:
    '/etc/apache2/conf.d/additional.conf':
      ensure: present
      owner: 'root'
      content: |
        BrowserMatch "check\_http"     dontlog

apache::area_osf_Redhat::resources:
  file:
    '/etc/httpd/conf.d/additional.conf':
      ensure: present
      owner: 'root'
      content: |
        BrowserMatch "check\_http"     dontlog

apache::area_monitoring_nrpe::require:
  - nrpe

apache::area_monitoring_nrpe::resources:
  package:
    perl:
      ensure: present
  nrpe::plugin:
    'apache_procs':
      check_command: 'check_procs'
      command_args: "--ereg-argument-array='^/usr/sbin/apache2' -w 4:200 -c 2:250"
    'apache_status':
      check_command: 'check_apapche_status'
      command_args: '-H localhost'
```

_modules/nrpe.yaml_
```yaml
nrpe::resources:
  class:
    - nrpe
  class_params:
    'nrpe':
      allowed_hosts: 'mon.example.com'
  nrpe::plugin:
    'load':
      check_command: 'check_load'
      command_args: '-w 4,3,2 -c 5,4,3'
```

## Feature: default values

Default values can be set for every resource type expect classes. They will be added as default values to the create resources call, so they only work for in hiera defined resources and not for resources created by loaded classes etc. It's possible to set default values at different levels:

1. Global for all modules
2. Local for a specific module
3. Local for a specific module area

If at different level default values for the same resource type are defined, then they get merged with priority to the most specialized definition.

### Example

Globally define that all files created by the file resource are owned by root if nothing other is configured:

_global.yaml_
```yaml
defaults::file:
  owner: root
  group: root
```

## Feature: Collections

Collections are used to realize virtual or exported resources. This should be handled in puppet modules in my opinion, but as we don't live in a perfect world with only perfect puppet modules, it can be sometimes necessary to realize resources in the node configuration.

### Example

Realize all exported sshkey resources:

_modules/standard.yaml_
```yaml
standard::collection:
  sshkey:
    type: exported
    query: ''
```

Realize all virtual resources with tag admin:

_role/webserver.yaml_
```yaml
standard::collection:
  user:
    type: virtual
    query: 'tag == "admin"'
```

## Feature: Subresources

Subresources are resources that depend on another "parent" resource. A subresource gets automatically added a requirement to the parent resource.

### Example

Parent resource user and adding a subresource ssh_authorized_key.

_modules/user.yaml_
```yaml
user::resources:
  'doe':
    comment: 'John Doe'
    ensure: present
    uid: 1000
    subresources:
      ssh_authorized_key:
        key1:
          type: 'ssh-rsa'
          key: 'AAA[..]=='

adminusers::default_mapping::from_user_to_ssh_authorized_key:
  title: 
    user:
    target: '/etc/ssh/authorized_key/&{title}'
  ensure: 'ensure'
```

By default only the ensure attribute is mapped from the parent resource to the subresource. But it is possible to map other attributes as well vie the _default_mapping_ key. It is possible to map a attribute of the parent resource to multiple attributes in the subresource. Also values can be transformed as show above.
There are some limitations which attributes can be mapped from parent to subresources:

1. Only in hiera defined attributes can be mapped. Default values set by the resource can't because they aren't known at the time the mapping take place.
2. It isn't possible to transform values of the subresource
3. The mapped parent values are added as default values at creation to the subresource, so isn't possible to override them by explicitly setting them in the subresource

## Feature: Default subresources for resource types

Default subresources are resources that get added as subresource to a certain resource type by default.

### Example

By default bless every user with the one true editor:

```yaml
adminusers::defaultsubresources::user:
  hiera::file:
    'inputrc':
       path: '.inputrc'
       mode: 0644
       content: |
         set editing-mode vi
```

