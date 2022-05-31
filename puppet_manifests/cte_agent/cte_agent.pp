# @summary Implement- Cipher Trust Transparent Encryption Agent (CTE Agent) Installation
#
class base::cte_agent (
  Stdlib::HTTPUrl $cte_source,
  String $reg_token,
  String $server_hostname,
  Variant[Enum['present', 'absent'], String] $ensure = ($facts['ec2_tags'] and $facts['ec2_tags']['CipherTrustManagement'] and downcase($facts['ec2_tags']['CipherTrustManagement']) == 'true') ? {true => 'present', default => 'absent'},
) {
  case $facts['kernel'] {
    'Linux': {
      if ($ensure == 'present') {
        $answer_file = '/tmp/CTEinstallAnswer.conf'
        $scratch_dir = lookup('name' => 'scratch_dir', 'default_value' => '/opt/puppetlabs/scratch')

        # Setup CTE Agent Installer Answer File
        file { $answer_file :
          ensure  => 'present',
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          content => epp('base/CTEinstallAnswer.conf.epp', {
            'reg_token'       => $reg_token,
            'server_hostname' => $server_hostname,
          }),
        }

        #Download CTE agent
        file { "${scratch_dir}/vee-fs-7.1.1-71-rh8-x86_64.bin":
          ensure => 'present',
          source => "${cte_source}/vee-fs-7.1.1-71-rh8-x86_64.bin",
          owner  => 'root',
          group  => 'root',
          mode   => '0755',
        }

        # Install CTE agent
        exec { 'Vormetric agent installation':
          command => "${scratch_dir}/vee-fs-7.1.1-71-rh8-x86_64.bin -s ${answer_file} -t ${scratch_dir}",
          require => [
                      File[$answer_file],
                      File["${scratch_dir}/vee-fs-7.1.1-71-rh8-x86_64.bin"]
          ],
          unless  => 'ls /bin/vmsec',
          path    => ['/usr/bin', '/usr/sbin', '/bin'],
        }
      }
    }
    'windows': {
      if ($ensure == 'present') {
        # Install CTE agent.
        # NOTE: This will reboot after installation unless "REBOOT=ReallySuppress" is provided.
        # Since this is optionally installed via an EC2 tag, the ec2 owner will understand this requirement.
        winstall::product { 'CipherTrust Transparent Encryption':
          ensure          => installed,
          source          => "${cte_source}/vee-fs-7.2.0-128-win64.exe",
          install_options => ['/s', '/qn'],
        }
      }
    }
    default: {
      fail('CTE Agent is not yet supported on this platform.')
    }
  }
}
