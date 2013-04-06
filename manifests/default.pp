define append_if_no_such_line($file, $line, $refreshonly = 'false') {
   exec { "/bin/echo '$line' >> '$file'":
      unless      => "/bin/grep -Fxqe '$line' '$file'",
      path        => "/bin",
      refreshonly => $refreshonly,
   }
}

class must-have {
  include apt
  apt::ppa { "ppa:webupd8team/java": }

  $confluence_home = "/vagrant/confluence-home"
  $confluence_version = "5.1"

  exec { 'apt-get update':
    command => '/usr/bin/apt-get update',
    before => Apt::Ppa["ppa:webupd8team/java"],
  }

  exec { 'apt-get update 2':
    command => '/usr/bin/apt-get update',
    require => [ Apt::Ppa["ppa:webupd8team/java"], Package["git-core"] ],
  }

  package { ["vim",
             "curl",
             "git-core",
             "bash"]:
    ensure => present,
    require => Exec["apt-get update"],
    before => Apt::Ppa["ppa:webupd8team/java"],
  }

  package { ["oracle-java7-installer"]:
    ensure => present,
    require => Exec["apt-get update 2"],
  }

  file { "confluence.properties":
    path => "/vagrant/atlassian-confluence-${confluence_version}/confluence/WEB-INF/classes/confluence-init.properties",
    content => "confluence.home=${confluence_home}",
    require => Exec["create_confluence_home"],
  }

  exec {
    "accept_license":
    command => "echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections && echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections",
    cwd => "/home/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Package["curl"],
    before => Package["oracle-java7-installer"],
    logoutput => true,
  }

  exec {
    "download_confluence":
    command => "curl -L http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${confluence_version}.tar.gz | tar zx",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Exec["accept_license"],
    logoutput => true,
    creates => "/vagrant/atlassian-confluence-${confluence_version}",
  }

  exec {
    "create_confluence_home":
    command => "mkdir -p ${confluence_home}",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => Exec["download_confluence"],
    logoutput => true,
    creates => "${confluence_home}",
  }

  exec {
    "start_confluence_in_background":
    environment => "CONFLUENCE_HOME=${confluence_home}",
    command => "/vagrant/atlassian-confluence-${confluence_version}/bin/start-confluence.sh &",
    cwd => "/vagrant",
    user => "vagrant",
    path    => "/usr/bin/:/bin/",
    require => [ Package["oracle-java7-installer"],
                 Exec["accept_license"],
                 Exec["download_confluence"],
                 Exec["create_confluence_home"] ],
    logoutput => true,
  }

  append_if_no_such_line { motd:
    file => "/etc/motd",
    line => "Run Confluence with: CONFLUENCE_HOME=${confluence_home} /vagrant/atlassian-confluence-${confluence_version}/bin/start-confluence.sh",
    require => Exec["start_confluence_in_background"],
  }
}

include must-have
