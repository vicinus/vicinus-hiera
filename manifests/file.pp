define hiera::file (
  $basedir = 'NOTSET',
  $path = 'NOTSET',
  $ensure = 'NOTSET',
  $backup = 'NOTSET',
  $checksum = 'NOTSET',
  $content = 'NOTSET',
  $ctime = 'NOTSET',
  $force = 'NOTSET',
  $group = 'NOTSET',
  $ignore = 'NOTSET',
  $links = 'NOTSET',
  $mode = 'NOTSET',
  $mtime = 'NOTSET',
  $owner = 'NOTSET',
  $provider = 'NOTSET',
  $purge = 'NOTSET',
  $recurse = 'NOTSET',
  $recurselimit = 'NOTSET',
  $replace = 'NOTSET',
  $selinux_ignore_defaults = 'NOTSET',
  $selrange = 'NOTSET',
  $selrole = 'NOTSET',
  $seltype = 'NOTSET',
  $seluser = 'NOTSET',
  $show_diff = 'NOTSET',
  $source = 'NOTSET',
  $sourceselect = 'NOTSET',
  $target = 'NOTSET',
  $type = 'NOTSET',

  $contenthash = 'NOTSET',
  $contenthashmerger = ' = ',
  $contenthasharray = 'NOTSET',
) {

  $real_path = $path ? {
    'NOTSET' => undef,
    /^\//     => $path,
    default => "${basedir}/$path",
  }
  $real_ensure = $ensure ? {
    'NOTSET' => undef,
    default => $ensure,
  }
  $real_backup = $backup ? {
    'NOTSET' => undef,
    default => $backup,
  }
  $real_checksum = $checksum ? {
    'NOTSET' => undef,
    default => $checksum,
  }
  $real_content = $content ? {
    'NOTSET' => $contenthash ? {
      'NOTSET' => $contenthasharray ? {
        'NOTSET' => undef,
        default => join(values_sort_by_keys($contenthasharray), "\n"),
      },
      default => join(sort(join_keys_to_values($contenthash, $contenthashmerger)), "\n"),
    },
    default => $content,
  }
  $real_ctime = $ctime ? {
    'NOTSET' => undef,
    default => $ctime,
  }
  $real_force = $force ? {
    'NOTSET' => undef,
    default => $force,
  }
  $real_group = $group ? {
    'NOTSET' => undef,
    default => $group,
  }
  $real_ignore = $ignore ? {
    'NOTSET' => undef,
    default => $ignore,
  }
  $real_links = $links ? {
    'NOTSET' => undef,
    default => $links,
  }
  $real_mode = $mode ? {
    'NOTSET' => undef,
    default => $mode,
  }
  $real_mtime = $mtime ? {
    'NOTSET' => undef,
    default => $mtime,
  }
  $real_owner = $owner ? {
    'NOTSET' => undef,
    default => $owner,
  }
  $real_provider = $provider ? {
    'NOTSET' => undef,
    default => $provider,
  }
  $real_purge = $purge ? {
    'NOTSET' => undef,
    default => $purge,
  }
  $real_recurse = $recurse ? {
    'NOTSET' => undef,
    default => $recurse,
  }
  $real_recurselimit = $recurselimit ? {
    'NOTSET' => undef,
    default => $recurselimit,
  }
  $real_replace = $replace ? {
    'NOTSET' => undef,
    default => $replace,
  }
  $real_selinux_ignore_defaults = $selinux_ignore_defaults ? {
    'NOTSET' => undef,
    default => $selinux_ignore_defaults,
  }
  $real_selrange = $selrange ? {
    'NOTSET' => undef,
    default => $selrange,
  }
  $real_selrole = $selrole ? {
    'NOTSET' => undef,
    default => $selrole,
  }
  $real_seltype = $seltype ? {
    'NOTSET' => undef,
    default => $seltype,
  }
  $real_seluser = $seluser ? {
    'NOTSET' => undef,
    default => $seluser,
  }
  $real_show_diff = $show_diff ? {
    'NOTSET' => undef,
    default => $show_diff,
  }
  $real_source = $source ? {
    'NOTSET' => undef,
    default => $source,
  }
  $real_sourceselect = $sourceselect ? {
    'NOTSET' => undef,
    default => $sourceselect,
  }
  $real_target = $target ? {
    'NOTSET' => undef,
    default => $target,
  }
  $real_type = $type ? {
    'NOTSET' => undef,
    default => $type,
  }

  file { $name:
    path => $real_path,
    ensure => $real_ensure,
    backup => $real_backup,
    checksum => $real_checksum,
    content => $real_content,
    ctime => $real_ctime,
    force => $real_force,
    group => $real_group,
    ignore => $real_ignore,
    links => $real_links,
    mode => $real_mode,
    mtime => $real_mtime,
    owner => $real_owner,
    provider => $real_provider,
    purge => $real_purge,
    recurse => $real_recurse,
    recurselimit => $real_recurselimit,
    replace => $real_replace,
    selinux_ignore_defaults => $real_selinux_ignore_defaults,
    selrange => $real_selrange,
    selrole => $real_selrole,
    seltype => $real_seltype,
    seluser => $real_seluser,
    show_diff => $real_show_diff,
    source => $real_source,
    sourceselect => $real_sourceselect,
    target => $real_target,
    type => $real_type,
  }
}
