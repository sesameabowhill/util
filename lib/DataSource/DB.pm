## $Id$
package DataSource::DB;

use strict;
use warnings;

use DBI;
use File::Spec;
use IPC::Run3;

use Sesame::Config;

sub new {
    my ($class, $is_sesame_5) = @_;

    my $self = {
    	'read_only' => 0,
        'statements' => [],
        'categories' => {},
        'affected_clients' => {},
    };

    my $core_config = $class->read_config('sesame_core.conf');
    my $detect_sesame_5 = exists $core_config->{'database_access'}{'database_name'};
    unless (defined $is_sesame_5) {
    	$is_sesame_5 = $detect_sesame_5;
    }
    if ($is_sesame_5) {
    	if ($detect_sesame_5) {
	    	$self->{'db'} = {
	    		'user'     => $core_config->{'database_access'}{'user'},
	    		'host'     => $core_config->{'database_access'}{'server_address'},
	    		'port'     => $core_config->{'database_access'}{'server_port'},
	    		'password' => $core_config->{'database_access'}{'password'},
	    		'database' => $core_config->{'database_access'}{'database_name'},
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
	    	};
    	}
    	else {
	    	$self->{'db'} = {
	    		'user'     => $core_config->{'database_access'}{'user'},
	    		'host'     => $ENV{'SESAME_DB_SERVER'},
	    		'port'     => 3306,
	    		'password' => $core_config->{'database_access'}{'password'},
	    		'database' => '',
	    	};
    	}
    	require DataSource::DB::Sesame_4;
    	$class = 'DataSource::DB::Sesame_4';
    }
    $self->{'dbh'} = _get_connection($self, $self->{'db'}{'database'});

    return bless $self, $class;
}

sub new_4 {
	my ($class) = @_;

	return $class->new(0);
}

sub new_5 {
	my ($class) = @_;

	return $class->new(1);
}

sub read_config {
	my ($class, $file_name) = @_;

	return Sesame::Config->read_file($file_name);
}

sub set_read_only {
	my ($self, $flag) = @_;

	$self->{'read_only'} = $flag;
}

sub is_read_only {
	my ($self) = @_;

	return $self->{'read_only'};
}

sub get_statements {
    my ($self) = @_;

    return [ sort @{ $self->{'statements'} } ];
}

sub save_sql_commands_to_file {
	my ($self, $file_name) = @_;

	open(my $fh, '>', $file_name) or die "can't write [$file_name]: $!";
	print $fh "-- $file_name\n";
	for my $sql_cmd (sort @{ $self->{'statements'} }) {
		print $fh "$sql_cmd;\n";
	}
	close($fh);
}

sub get_affected_clients {
    my ($self) = @_;

    return [ sort keys %{ $self->{'affected_clients'} } ];
}

sub add_statement {
	my ($self, $sql) = @_;

	push(
        @{ $self->{'statements'} },
        $sql,
	);
}

sub add_category {
	my ($self, $category) = @_;

	$self->{'categories'}{$category} ++;
}

sub get_categories_stat {
	my ($self) = @_;

	return $self->{'categories'};
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