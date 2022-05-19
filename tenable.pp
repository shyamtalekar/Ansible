# @summary Install and configure the Tenable Agent
#
# @param host The Tenable Server Agent fqdn
# @param port The Tenable Server Agent port
# @param group The Tenable Server Agent group
# @param version The version of the Tenable Agent to be installed
# @param license _key The license key for all Tenable Agents
# @param source_url The URL source of the Tenable Agent package
#
# @api private
#
class base::tenable(
  Stdlib::Host $host,
  Stdlib::Port $port,
  String $group,
  String $version,
  Optional[String] $license_key,
  Stdlib::HTTPUrl $source_url,
) {
  # Validate license key
  if str2bool($facts['ami_build']) or $license_key == '' or $license_key == undef {
    $service_ensure = 'stopped'
    $service_enable = false
  } else {
    $service_ensure = 'running'
    $service_enable = true
  }

  case $facts['kernel'] {
    'Linux': {
      $tenable_rpm = "${source_url}/NessusAgent-${version}-es${facts['operatingsystemmajrelease']}.x86_64.rpm"
      $tenable_service = 'nessusagent'

      # Install tenable agent.
      package { 'NessusAgent':
        ensure => $version,
        source => $tenable_rpm,
        before => Service[$tenable_service],
      }

      # Register tenable nessus agent to server.
      if str2bool($facts['ami_build']) or $license_key == '' or $license_key == undef {
        notice("Skipping tenable agent registration to ${host}")
      } else {
        exec { 'Link Tenable agent':
          path    => '/usr/bin:/opt/nessus_agent/sbin',
          command => @("END"),
                     nessuscli fix --set process_priority='low'
                     nessuscli fix --set update_hostname='yes'
                     nessuscli agent link --key=${license_key} --host=${host} --port=${port} --groups=${group}
                     |END
          onlyif  => "nessuscli agent status | grep -q 'Not linked'",
          require => Package['NessusAgent'],
          notify  => Service[$tenable_service],
        }
      }
    }
    'windows': {
      $tenable_msi = "${source_url}/NessusAgent-${version}-x64.msi"
      $tenable_service = 'Tenable Nessus Agent'

      # Install tenable agent.
      winstall::product { 'Nessus Agent (x64)':
        ensure          => installed,
        source          => $tenable_msi,
        install_options => ['/qn'],
        before          => Service[$tenable_service ]
      }

      # Register tenable nessus agent to server.
      if str2bool($facts['ami_build']) or $license_key == '' or $license_key == undef {
        notice("Skipping tenable agent registration to ${host}")
      } else {
        exec { 'Link Tenable agent':
          path     => 'C:\Program Files\Tenable\Nessus Agent',
          provider => powershell,
          command  => @("END"/L),
                      & 'C:\Program Files\Tenable\Nessus Agent\nessuscli' fix --set process_priority='low'
                      & 'C:\Program Files\Tenable\Nessus Agent\nessuscli' fix --set update_hostname='yes'
                      & 'C:\Program Files\Tenable\Nessus Agent\nessuscli' agent link --key=${license_key}\
                        --host=${host} --port=${port} --groups=${group}
                      |END
          onlyif   => @("END"/L$),
                      \$found = (& 'C:\Program Files\Tenable\Nessus Agent\nessuscli' agent status\
                       | Select-String -Pattern 'Not linked' -Quiet) 
                      if (\$found -eq \$null) { exit 1 } else { exit 0 }
                      |END
          require  => Winstall::Product['Nessus Agent (x64)'],
          notify   => Service[$tenable_service],
        }
      }
    }
    default: {
      fail('Nessus Tenable Agent is not yet supported on this platform.')
    }
  }

  # Setup agent service
  service { $tenable_service:
    ensure => $service_ensure,
    enable => $service_enable,
  }
}