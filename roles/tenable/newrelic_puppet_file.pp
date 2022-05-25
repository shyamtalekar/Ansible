# @summary Install the NewRelic agent
# 
# @param source_url The URL source of the NewRelic Agent package
#
# @api private
#
class base::newrelic(
    Optional[String] $license_key,
    Optional[Boolean] $fedramp,
)   {
# Validate license key
    if str2bool($facts['ami_build']) or $license_key == '' or $license_key == undef {
    $service_ensure = 'stopped'
    $service_enable = false
}   else {
    $service_ensure = 'running'
    $service_enable = true
  }

  case $facts['kernel'] {
    'Linux': {
      $newrelic_rpm = "${base::nr_source}/newrelic-infra-${base::nr_version}.el${facts['operatingsystemmajrelease']}.x86_64.rpm"
      $newrelic_service = 'newrelic'

      # Install NewRelic dependecy tdagent from artifactory.
      package {'td-agent-bit':
        ensure => $base::tdagent_version,
        source => $base::tdagent_source,
      }
      # Install NewRelic agen
      package { 'newrelic-infra':
        ensure  => "${base::nr_version}.el${facts['operatingsystemmajrelease']}",
        source  => $newrelic_rpm,
        require => Package['td-agent-bit'],
      }

      # Register agent to web/master console.
      if str2bool($facts['ami_build']) or $license_key == '' or $license_key == undef {
        notice("Skipping newrelic agent registration to ${::host}")
      } else {
        file { '/etc/newrelic-infra.yml':
          ensure  => 'present',
          owner   => 'root',
          group   => 'root',
          mode    => '0640',
          require => Package['newrelic-infra'],
          content => epp('base/newrelic-infra.yml.epp', {
              license_key => $license_key,
              log_file    => '/var/log/newrelic-infra.log',
              fedramp     => $fedramp,
          }),
          notify  => Service['newrelic-infra'],
        }

        service {'newrelic-infra':
          ensure => 'running',
          enable =>  true,
        }
      }
    }
    'windows': {
      # Install newrelic agent.
      winstall::product { 'New Relic Infrastructure Agent':
        ensure          => $base::nr_version,
        source          => $base::nr_source,
        install_options => ['/qn'],
      }

      # Register agent to web/master console.
      if str2bool($facts['ami_build']) or $license_key == '' or $license_key == undef {
        notice("Skipping newrelic agent registration to ${::host}")
      } else {
          file  { 'C:/Program Files/New Relic/newrelic-infra/newrelic-infra.yml':
            ensure  => 'present',
            content => epp('base/newrelic-infra.yml.epp', {
              license_key => $license_key,
              log_file    => 'C:/Program Files/New Relic/newrelic-infra/newrelic-infra.log',
              fedramp     => $fedramp,
            }),
            notify  => Service['newrelic-infra'],
            require => Winstall::Product['New Relic Infrastructure Agent'],
        }

        service {'newrelic-infra':
          ensure => 'running',
          enable =>  true,
        }
      }
    }
    default: {
      fail('Newrelic Agent is not yet supported on this platform.')
    }
  }
}