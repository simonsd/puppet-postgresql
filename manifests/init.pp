class postgresql::packages {
	package { 'postgresql':
		ensure => latest,
		name => $operatingsystem ? {
			debian => 'postgresql',
			default => 'postgresql-server',
		},
		require => $operatingsystem ? {
			debian => undef,
			default => Yumrepo['psql'],
		},
	}

	exec { 'postgresql_initdb':
		command => $operatingsystem ?{
			debian => 'true',
			default => '/etc/init.d/postgresql initdb',
		},
		path => '/bin:/usr/bin',
		unless => 'ls /var/lib/pgsql/data/ | wc -l | grep -v "^0$"',
		require => Package['postgresql'],
	}

	service { 'postgresql':
		ensure => running,
		enable => true,
        hasstatus => true,
		require => [ Package['postgresql'], Exec['postgresql_initdb'] ],
	}
}
class postgresql::config {
	file { '/etc/postgresql':
		ensure => directory,
	}

	file { '/etc/postgresql/8.4':
		ensure => directory,
		require => File['/etc/postgresql'],
	}

	file { '/etc/postgresql/8.4/main':
		ensure => directory,
		require => File['/etc/postgresql/8.4'],
	}

	file { 'postgresql.conf':
		ensure => present,
		path => '/etc/postgresql/8.4/main/postgresql.conf',
		owner => postgres,
		group => postgres,
		mode => 644,
		content => template('postgresql/postgresql.conf.erb'),
		notify => Service['postgresql'],
		require => [ Package['postgresql'], File['/etc/postgresql/8.4/main'] ],
	}

	file { 'pg_hba.conf':
		ensure => present,
		path => '/etc/postgresql/8.4/main/pg_hba.conf',
		owner => postgres,
		group => postgres,
		mode => 644,
		content => template('postgresql/pg_hba.conf.erb'),
		notify => Service['postgresql'],
		require => Package['postgresql'],
	}

	exec { 'openerp_create_db':
		path => '/bin:/usr/bin',
		command => 'createdb openerp',
		user => 'postgres',
		unless => 'psql -l | grep openerp',
		require => Service['postgresql'],
        before => Service['openerp']
	}

	exec { 'openerp_create_user':
		path => '/bin:/usr/bin',
        command => "psql -c \"create user openerp with password 'openerp' createdb nocreaterole\"",
		user => 'postgres',
		unless => "psql -c '\\du'|grep '^ openerp'",
        require => Service['postgresql'],
	}

	exec { 'openerp_grant_perms':
		path => '/bin:/usr/bin',
		command => "psql -c \"grant all privileges on database openerp to openerp\"",
        user => 'postgres',
		unless => 'psql -l|grep openerp',
		require => Exec['openerp_create_db', 'openerp_create_user'],
	}
}
