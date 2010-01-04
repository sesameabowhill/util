## $Id$
package DataSource::DB;

use strict;
use warnings;

use DBI;

use Sesame::Config;

sub new {
    my ($class) = @_;

    my $self = {
        'statements' => [],
        'affected_clients' => {},
    };

    my $core_config = $class->read_config('sesame_core.conf');
    if (exists $core_config->{'database_access'}{'database_name'}) {
    	$self->{'db'} = {
    		'user'     => $core_config->{'database_access'}{'user'},
    		'host'     => $core_config->{'database_access'}{'server_address'},
    		'port'     => $core_config->{'database_access'}{'server_port'},
    		'password' => $core_config->{'database_access'}{'password'},
    		'database' => $core_config->{'database_access'}{'database_name'},
    	};
    	require DataSource::DB::Sesame_5;
    	$class = 'DataSource::DB::Sesame_5';
    }
    else {
    	$self->{'db'} = {
    		'user'     => $core_config->{'database_access'}{'user'},
    		'host'     => $ENV{'SESAME_DB_SERVER'},
    		'port'     => 3306,
    		'password' => $core_config->{'database_access'}{'password'},
    		'database' => '',
    	};
    	require DataSource::DB::Sesame_4;
    	$class = 'DataSource::DB::Sesame_4';
    }
    $self->{'dbh'} = get_connection($self, $self->{'db'}{'database'});

    return bless $self, $class;
}

sub read_config {
	my ($class, $file_name) = @_;

	return Sesame::Config->read_file($file_name);
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

sub get_connection {
    my ($self, $db_name) = @_;

    $db_name ||= '';

    return DataSource::DB::DBI->connect(
        "DBI:mysql:host=".$self->{'db'}{'host'}.':'.$self->{'db'}{'port'}.($db_name?";database=$db_name":""),
        $self->{'db'}{'user'},
        $self->{'db'}{'password'},
        {
            'RaiseError' => 1,
            'ShowErrorStatement' => 1,
            'PrintError' => 0,
        }
    );
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