class exim::config {
  $local_domains_txt = join($exim::local_domains, ' : ')
  $relay_to_domains_txt = join($exim::relay_to_domains, ' : ')
  $relay_from_hosts_txt = join($exim::relay_from_hosts + ['localhost'], ' : ')
  $daemon_smtp_ports_txt = join($exim::daemon_smtp_ports, ' : ')
  $never_users_txt = join($exim::never_users, ' : ')
  $host_lookup_txt = join($exim::host_lookup, ' : ')
  $sender_unqualified_hosts_txt = join($exim::sender_unqualified_hosts, ' : ')
  $recipient_unqualified_hosts_txt = join($exim::recipient_unqualified_hosts, ' : ')

  if $exim::custom_config {
    $config_file_content = $exim::custom_config
  } else {
    if $exim::acl_config {
      $acl_config = $exim::acl_config
    } else {
      $acl_config = template('exim/acl.conf.erb')
    }
    $config_file_content = template('exim/exim.conf.erb')
  }

  file {
    $exim::config_file:
      ensure    => 'present',
      owner     => 'root',
      group     => $exim::service_group,
      mode      => '0440',
      content   => $config_file_content,
      show_diff => $exim::config_file_show_diff,
      notify    => Service[$exim::service_name];
  }

  if $exim::dkim_sign {
    file {
      $exim::dkim_keys_path:
        ensure => 'directory',
        owner  => 'root',
        group  => $exim::service_group,
        mode   => '0440';
    }

    concat {
      $exim::dkim_config_file:
        ensure         => 'present',
        owner          => 'root',
        group          => $exim::service_group,
        mode           => '0440',
        ensure_newline => true;
    }

    $exim::dkim_keys.each |$domain, $key| {
      file {
        "${exim::dkim_keys_path}/${domain}.key":
          ensure    => 'present',
          owner     => 'root',
          group     => $exim::service_group,
          mode      => '0440',
          content   => "${key['key']}\n",
          show_diff => false;
      }

      concat::fragment {
        "exim dkim configuration for ${domain}":
          target  => $exim::dkim_config_file,
          content => template('exim/dkim.conf.erb');
      }
    }
  }

  if $exim::tls_enabled {
    if $exim::tls_manage_certs {
      unless $exim::tls_certificate_content and $exim::tls_privatekey_content {
        fail('You must provide tls_certificate_content and tls_privatekey_content when tls_enabled and tls_manage_certs are true')
      }

      file {
        $exim::tls_certificate_path:
          ensure  => 'present',
          owner   => 'root',
          group   => 'root',
          mode    => '0444',
          content => "${exim::tls_certificate_content}\n",
          notify  => Service[$exim::service_name];

        $exim::tls_privatekey_path:
          ensure    => 'present',
          owner     => 'root',
          group     => $exim::service_group,
          mode      => '0440',
          content   => "${exim::tls_privatekey_content}\n",
          show_diff => false,
          notify    => Service[$exim::service_name];
      }
    }

    if $exim::auth_ldap_enable {
      unless $exim::ldap_hostname and $exim::ldap_base_dn and $exim::ldap_bind_dn and $exim::ldap_passwd {
        fail('You must provide all ldap_* parameters when auth_ldap_enable is true')
      }
    }
  }

  service {
    $exim::service_name:
      ensure => 'running',
      enable => true;
  }

  if $exim::create_mta_fact {
    file {
      $exim::mta_fact_file:
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => to_yaml({'mta' => 'exim'});
    }
  } else {
    file {
      $exim::mta_fact_file:
        ensure => 'absent';
    }
  }
}
