## $Id$
package DataSource::DB;

use strict;
use warnings;

use DBI;
use File::Spec;
use IPC::Run3;

use base 'DataSource::Base';

sub new {
	my ($class, $is_sesame_5, $db_connection_string) = @_;

	my $self = {
		'read_only' => 0,
		'statements' => [],
		'affected_clients' => {},
	};

	my $core_config = $class->read_config('sesame_core.conf');
	my $detect_sesame_5 = exists $core_config->{'database_access'}{'database_name'};
	my $detect_sesame_6 = exists $core_config->{'database_access'}{'versioned_tables'};
	unless (defined $is_sesame_5) {
		$is_sesame_5 = ( $detect_sesame_6 ? 2 : ($detect_sesame_5 ? 1 : 0) );
	}
	if ($is_sesame_5 == 2) {
		$self->{'db'} = {
			'user'     => $core_config->{'database_access'}{'user'},
			'host'     => $core_config->{'database_access'}{'server_address'},
			'port'     => $core_config->{'database_access'}{'server_port'},
			'password' => $core_config->{'database_access'}{'password'},
			'database' => $core_config->{'database_access'}{'database_name'},
			'version'  => 6,
		};
		my %param_map = (
			'database' => 'persistSchema',
			'host'     => 'persistHost',
			'password' => 'persistPassword',
			'port'     => 'persistPort',
			'user'     => 'persistUser',
		);
		while (my ($param, $env_var) = each %param_map) {
			if (exists $ENV{$env_var} && exists $self->{'db'}{$param}) {
				$self->{'db'}{$param} = $ENV{$env_var};
			}
		}
		require DataSource::DB::Sesame_6;
		$class = 'DataSource::DB::Sesame_6';
	} elsif ($is_sesame_5 == 1) {
		if ($detect_sesame_5) {
			$self->{'db'} = {
				'user'     => $core_config->{'database_access'}{'user'},
				'host'     => $core_config->{'database_access'}{'server_address'},
				'port'     => $core_config->{'database_access'}{'server_port'},
				'password' => $core_config->{'database_access'}{'password'},
				'database' => $core_config->{'database_access'}{'database_name'},
				'version'  => 5,
			};
		}
		else {
			die "can't access sesame5 from sesame4";
		}
		require DataSource::DB::Sesame_5;
		$class = 'DataSource::DB::Sesame_5';
	}
	else {
		if ($detect_sesame_5) {
			## use hardcoded params to access sesame4 from sesame5
			$self->{'db'} = {
				'user'     => 'admin',
				'host'     => 'digger',
				'port'     => 3306,
				'password' => 'higer4',
				'database' => '',
				'version'  => 4,
			};
		}
		else {
			$self->{'db'} = {
				'user'     => $core_config->{'database_access'}{'user'},
				'host'     => $ENV{'SESAME_DB_SERVER'},
				'port'     => 3306,
				'password' => $core_config->{'database_access'}{'password'},
				'database' => '',
				'version'  => 4,
			};
		}
		require DataSource::DB::Sesame_4;
		$class = 'DataSource::DB::Sesame_4';
	}
	if (defined $db_connection_string) {
		## admin:higer4@127.0.0.1:3306/sesame_db
		if ($db_connection_string =~ m{^(\w+):(\w+)\@([\w.-]+)(?::(\d+))?/(\w+)$}) {
			$self->{'db'} = {
				'user'     => $1,
				'password' => $2,
				'host'     => $3,
				'port'     => ($4 || 3306),
				'database' => $5,
			};
		}
		else {
			die "invalid connection string [$db_connection_string]";
		}
	}
	$self->{'dbh'} = _get_connection($self, $self->{'db'}{'database'});

	return bless $self, $class;
}

sub new_4 {
	my ($class, $db_connection_string) = @_;

	return $class->new(0, $db_connection_string);
}

sub new_5 {
	my ($class, $db_connection_string) = @_;

	return $class->new(1, $db_connection_string);
}

sub new_6 {
	my ($class, $db_connection_string) = @_;

	return $class->new(2, $db_connection_string);
}

sub read_config {
	my ($class, $file_name) = @_;

	my $config_file = File::Spec->join($ENV{'SESAME_ROOT'}, 'sesame', 'config', $file_name);
	open(my $f, "<", $config_file) or die "can't read config [$config_file]: $!";
	local $/;
	my $config_data = <$f>;
	close($f);

	my $data = eval( $config_data ) or die("Can't parse data from [$config_file]: $@");
	return $data;
}


sub get_affected_clients {
	my ($self) = @_;

	return [ sort keys %{ $self->{'affected_clients'} } ];
}

sub _get_connection {
	my ($self, $db_name) = @_;

	$db_name ||= '';

	return DataSource::DB::DBI->connect(
		"DBI:mysql:host=".$self->{'db'}{'host'}.';port='.$self->{'db'}{'port'}.($db_name?";database=$db_name":""),
		$self->{'db'}{'user'},
		$self->{'db'}{'password'},
		{
			'RaiseError' => 1,
			'ShowErrorStatement' => 1,
			'PrintError' => 0,
		}
	);
}

sub expand_client_group {
	my ($self, $clients) = @_;

	my @groups  = grep {$_ =~ m{^:}} @$clients;
	my @clients = grep {$_ !~ m{^:}} @$clients;
	for my $group (@groups) {
		my $usernames;
		if ($group eq ':all') {
			$usernames = $self->_get_all_clients_username();
		}
		elsif ($group eq ':all_active') {
			$usernames = $self->_get_all_clients_username(1);
		}
		else {
			die "unknown group [$group] (use :all_active or :all)";
		}
		push(@clients, @$usernames);
	}
	for my $client_db (@clients) {
		if ($client_db =~ m{^\d+$}) {
			my $client_data = $self->get_client_data_by_id($client_db);
			unless (defined $client_data->get_username()) {
				die "can't find client by id [$client_db]";
			}
			$client_db = $client_data->get_username();
		}
	}
	my %unique_usernames;
	## remove duplicates
	@clients = grep { !$unique_usernames{$_}++ } @clients;
	return \@clients;
}

sub get_connection_info {
	my ($self) = @_;

	my $user = $self->{'dbh'}->selectrow_array("SELECT user()");
	my $database = $self->{'dbh'}->selectrow_array("SELECT database()");
	#my $connection_id = $self->{'dbh'}->selectrow_array("SELECT connection_id()");
	my $connection_info = $self->{'dbh'}->get_info(2);

	return sprintf(
		"%s%s%s %s%s",
		$user,
		(defined $database?"/$database":''),
		($self->is_read_only()?' "readonly"':''),
		$connection_info,
		($self->{'db'}{'version'} ? " v".$self->{'db'}{'version'} : ""),
	);
}

sub _do_query {
	my ($self, $sql_pattern, $params) = @_;

	my $sql = sprintf($sql_pattern, map { $self->{'dbh'}->quote($_) } @$params);
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	$self->add_statement($sql);

	if ($self->is_read_only()) {
		return undef;
	}
	else {
		$self->{'dbh'}->do($sql);
		return $self->{'dbh'}->{'mysql_insertid'};
	}
}

#sub get_single_db_connection {
#    my ($self, $db_name) = @_;
#
#    $db_name ||= '';
#
#	if (exists $self->{'last_connection'}) {
#		if ($self->{'last_db_name'} ne $db_name) {
#			die "can't switch DB name from [".$self->{'last_db_name'}."] to [$db_name]";
#		}
#	}
#	else {
#		$self->{'last_connection'} = $self->get_connection($db_name);
#		$self->{'last_db_name'} = $db_name;
#	}
#	return $self->{'last_connection'} ;
#}

sub _get_all_clincheck_files {
	my ($self, $folder) = @_;

	my @cmd = (
		'find',
		'-L',
		$folder,
		'-type', 'f',
		'-name', '*.txt',
	);
	my ($output, $err);
	run3(\@cmd, \undef, \$output, \$err);
	my @files;
	for my $fn (split m/\r?\n/, $output) {
		my @file_mtime = (localtime((stat($fn))[9]))[5, 4, 3];
		$file_mtime[0] += 1900;
		$file_mtime[1] ++;
		my ($id, $file) = (File::Spec->splitdir($fn))[-2, -1];
		my $params = _read_clinchecks_settings($fn) || {};
		($params->{'case_number'} = $file) =~ s/\.txt$//;
		($params->{'file_mask'}   = $fn)   =~ s/\.txt$/*/;
		$params->{'file'} = $fn;
		$params->{'file_mtime'} = sprintf('%04d-%02d-%02d', @file_mtime);
		push(@files, $params);
	}
	return \@files;
}

sub _read_clinchecks_settings {
	my ($file) = @_;

	local $/;
	open(my $f, "<", $file) or die "can't read [$file]: $!";
	my $data = <$f>;
	close($f);

	if ($data =~ m/---PTI Russia comments---(.*)---End of comments---/si) {
		my ($params_str) = ($1);
		my %params;
		for my $line (split m/\r?\n/, $params_str) {
			my ($key, $value) = split(m/:/, $line, 2);
			if (defined $key) {
				$params{$key} = $value;
			}
		}
		my @dt = split(m'/', $params{'Data'}, 3);
		$dt[2] += 2000;
		return {
			'date' => sprintf('%04d-%02d-%02d', @dt[2, 1, 0]),
			'stages' => $params{'Stages #'},
			#'case_number' => $params{'Patient Case Number'},
		};
	}
	else {
		return undef;
	}

#Patient First Name:Kelly
#Patient Last Name:Simmermaker
#Patient Case Number:1167917
#Patient ADF File Name:Kelly Simmermaker 07_30_09__13_05.adf
#Doctor ID:148
#Doctor login:rgakhal3
#Data:30/07/09
#Stages #:16

}

package DataSource::DB::DBI;

use base qw( DBI );

package DataSource::DB::DBI::db;

use Hash::Util qw( lock_keys );

use base qw( DBI::db );

sub selectall_arrayref {
	my ($sth, @args) = @_;

	my $result = $sth->SUPER::selectall_arrayref(@args) or return;
	for my $item (@$result) {
		if (ref $item eq 'HASH') {
			lock_keys(%$item);
		}
	}
	return $result;
}

sub selectrow_hashref {
	my ($sth, @args) = @_;

	my $result = $sth->SUPER::selectrow_hashref(@args) or return;
	if (ref $result eq 'HASH') {
		lock_keys(%$result);
	}
	return $result;
}

package DataSource::DB::DBI::st;

use base qw( DBI::st );



1;
