## $Id$ 
package DataSource::DB;

use strict;

use DBI;

use Sesame::Config;
use Sesame::Unified::Client;
use Sesame::Unified::ClientProperties;

sub new {
    my ($class) = @_;

    return bless {
        'dbh' => $class->get_connection(),
        'statements' => [],
        'affected_clients' => {},
    }, $class;
}

sub read_config {
	my ($self, $file_name) = @_;
	
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

sub remove_resource {
    my ($self, $guid) = @_;

    $self->add_statement(
        "DELETE FROM srm.resources WHERE id=" .
            $self->{'dbh'}->quote($guid)." LIMIT 1",
    );
}

sub add_statement {
	my ($self, $sql) = @_;
	
	push(
        @{ $self->{'statements'} },
        $sql,
	);
}

sub remove_guid_from_email_settings {
    my ($self, $client_ref, $guid) = @_;

    my $table_name = ( $client_ref->get_client_type() eq 'ortho' ? 'properties' : 'profile' );
    $self->add_statement(
        "UPDATE email_messaging.reminder_settings SET image_guid='' WHERE client_id=" .
            $self->{'dbh'}->quote($client_ref->get_id())." AND image_guid=" .
            $self->{'dbh'}->quote($guid),
    );
    $self->{'affected_clients'}{ $client_ref->get_db_name() } = 1;
}

sub remove_guid_from_properties {
    my ($self, $client_ref, $param, $guid) = @_;

    my $table_name = ( $client_ref->get_client_type() eq 'ortho' ? 'properties' : 'profile' );
    $self->add_statement(
        "UPDATE ".$client_ref->get_db_name().".$table_name SET SVal=NULL " .
            "WHERE PKey=".$self->{'dbh'}->quote($param)." AND SVal=" .
            $self->{'dbh'}->quote($guid),
    );
    $self->{'affected_clients'}{ $client_ref->get_db_name() } = 1;
}

sub get_srm_resources {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, container, path_from, date FROM srm.resources",
        { 'Slice' => {} },
    );
}

sub get_client_property {
    my ($self, $client_ref, $param) = @_;

    $self->{'dbh'}->do("USE ".$client_ref->get_db_name());
    my $client_prop = Sesame::Unified::ClientProperties->new(
        $client_ref->get_client_type(),
        $self->{'dbh'},
    );

    return $client_prop->get_property($param);
}

sub client_by_db {
    my ($self, $db) = @_;

    return Sesame::Unified::Client->new('db_name', $db);
}

sub get_client_data_by_db {
    my ($self, $db) = @_;
    
    require ClientData::DB;
    return ClientData::DB->new($self, $db);
}

sub get_clients {
    my ($self) = @_;

    return Sesame::Unified::Client->get_all_clients();
}

sub get_email_messaging_guids {
    my ($self, $client_id) = @_;

    return {
        map {@$_}
        grep {defined $_->[0] && length $_->[0]}
        @{
            $self->{'dbh'}->selectall_arrayref(
                "SELECT image_guid, count(*) FROM email_messaging.reminder_settings WHERE client_id=? GROUP BY 1",
                undef,
                $client_id,
            )
        }
    };
}

sub get_voice_clients {
	my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id as voice_client_id, db_name as cl_mysql FROM voice.Clients",
        { 'Slice' => {} },
    );
}

sub get_voice_end_messages_by_voice_client {
	my ($self, $voice_client_id) = @_;
	
    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, guid, name, voice_type FROM voice.EndMessage WHERE cid=?",
        { 'Slice' => {} },
        $voice_client_id,
    );
}

sub add_voice_end_message {
	my ($self, $voice_client_id, $title, $text, $guid, $voice_type, $status) = @_;	
	
	return $self->{'dbh'}->do(
		"INSERT INTO voice.EndMessage (id, cid, name, value, guid, updated, voice_type, status) " .
		"VALUES (NULL, ?, ?, ?, ?, NOW(), ?, ?)",
		undef,
		$voice_client_id,
		$title,
		$text,
		$guid,
		$voice_type, 
		$status,
	);
}

## static
sub is_client_exists {
    my ($class, $db_name) = @_;

    my $dbh = get_connection();
    return $db_name eq $dbh->selectrow_array("SHOW DATABASES LIKE ?", undef, $db_name);
}

sub get_connection {
    my ($class, $db_name) = @_;

    $db_name ||= '';

    return DataSource::DB::DBI->connect(
        "DBI:mysql:host=$ENV{SESAME_DB_SERVER}".($db_name?";database=$db_name":""),
        'admin',
        'higer4',
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



#sub fetch {
#    my ($sth, @args) = @_;
#    
#    my $row = $sth->SUPER::fetch(@args) or return;
#    if (ref $row eq 'HASH') {
#		Readonly %$row;    	
#    }
#    return $row;
#}

1;