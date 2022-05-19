# @summary Install and configure the MS_Defender
# @api private
#
# @param version The version of the MS Defender package
# @param source The URL source of the MS Defender registration script
#
class base::mdatp(
  Variant[Enum['present', 'absent'], String]  $ensure,
  String                                      $version,
  Stdlib::HTTPUrl                             $source,
  Boolean                                     $service_enabled,
  Variant[Enum['stopped', 'running'], String] $service_ensure,
  Optional[Array[String]]                     $excludedpaths,
  Optional[Array[String]]                     $excludedfilenames,
  Optional[Array[String]]                     $excludedfileextensions,
){
  case $facts['kernel'] {
    'Linux': {
      if ($ensure == 'present') {
        $defender_service = 'mdatp'
        $defender_script = '/opt/microsoft/mdatp/MicrosoftDefenderATPOnboardingLinuxServer.py'

        # Install defender service.
        package { $defender_service:
          ensure => $version,
          notify => Service[$defender_service],
        }

        # Custom alight configuration file Template.
        file { '/etc/opt/microsoft/mdatp/managed/mdatp_managed.json':
          ensure  => file,
          content => epp('base/mdatp_managed.json.epp', {
              'excludedpaths'          => $excludedpaths,
              'excludedfilenames'      => $excludedfilenames,
              'excludedfileextensions' => $excludedfileextensions
          }),
          owner   => 'root',
          group   => 'root',
          mode    => '0775',
          require => Package[$defender_service],
          notify  => Service[$defender_service],
        }

        # Register to centralized management (i.e., execute onboard script).
        archive { $defender_script:
          ensure  => present,
          source  => $source,
          require => Package[$defender_service],
        }
        -> file { $defender_script:
          ensure => 'present',
          mode   => '0755',
          notify => Exec['Register MS Defender']
        }

        exec { 'Register MS Defender':
          path    => '/usr/bin',
          command => "python3 ${defender_script}",
          onlyif  => 'mdatp health --field licensed | grep false',
          require =>  File[$defender_script],
        }

        # MS Defender Update
        # NOTE: Will update ms defender package weekly on wed at 6am.
        cron::weekly { 'ms_defender_update':
          ensure      => ($version != 'latest') ? { true => absent, default => present },
          minute      => '0',
          hour        => '6',
          weekday     => '3',
          user        => 'root',
          command     => 'yum update mdatp > /dev/null 2>&1',
          description => 'Updates MS Defender package (weekly)',
        }

        # Ensure MS Defender is always running or stopped when required.
        service { $defender_service:
          ensure => $service_ensure,
          enable => $service_enabled,
        }
      }
    }
    'windows': {
      if ($ensure == 'present') {
        $defender_service = 'WinDefend'
        $defender_script = 'C:/Windows/Temp/WindowsDefenderATPLocalOnboardingScript.cmd'

        # Enable MS Defender Service.
        exec { $defender_service:
          provider => powershell,
          command  => 'Install-WindowsFeature -Name Windows-Defender',
          onlyif   => @("END"/L$),
                      \$found = ((Get-WindowsFeature -Name Windows-Defender).InstallState | Select-String -Pattern 'Available' -Quiet)
                      if (\$found -eq \$null) { exit 1 } else { exit 0 }
                      |END
        }

        # NOTE: WinDefend service only exists after reboot.
        if (!str2bool($facts['ami_build'])) and $facts['ms_defender_services'].has_key($defender_service) {
          # Register to centralized management (i.e., execute onboard script).
          archive { $defender_script:
            ensure => present,
            source => $source,
          }

          exec { $defender_script:
            path     => 'C:/Windows/Temp',
            command  => "& '${defender_script}'",
            provider => powershell,
            onlyif   => @("END"/L$),
                        \$running = ((Get-Service -Name sense).Status | Select-String -Pattern 'Stopped' -Quiet)
                        if (\$running -eq \$null) { exit 1 } else { exit 0 }
                        |END
            require  => [
              Archive[$defender_script],
              Service[$defender_service],
            ]
          }

          # Ensure MS Defender (and Defender Firewall) is always running.
          service { [$defender_service, 'mpssvc']:
            ensure => $service_ensure,
            enable => $service_enabled,
          }
        } else {
          notify { 'MS Defender - Reboot':
            message => 'Reboot required to enable and onboard MS Defender.',
          }
        }
      }
    }
    default: {
      notify { 'Unsupported OS':
        message =>  'The base profile does not support this system.',
      }
    }
  }
}