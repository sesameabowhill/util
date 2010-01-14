## $Id$
package DataSource::DB::Sesame_4;

use strict;
use warnings;

#use Sesame::Unified::Client;
#use Sesame::Unified::ClientProperties;

use base qw( DataSource::DB );



sub remove_resource {
    my ($self, $guid) = @_;

    $self->add_statement(
        "DELETE FROM srm.resources WHERE id=" .
            $self->{'dbh'}->quote($guid)." LIMIT 1",
    );
}


#sub remove_guid_from_email_settings {
#    my ($self, $client_ref, $guid) = @_;
#
#    my $table_name = ( $client_ref->get_client_type() eq 'ortho' ? 'properties' : 'profile' );
#    $self->add_statement(
#        "UPDATE email_messaging.reminder_settings SET image_guid='' WHERE client_id=" .
#            $self->{'dbh'}->quote($client_ref->get_id())." AND image_guid=" .
#            $self->{'dbh'}->quote($guid),
#    );
#    $self->{'affected_clients'}{ $client_ref->get_db_name() } = 1;
#}
#
#sub remove_guid_from_properties {
#    my ($self, $client_ref, $param, $guid) = @_;
#
#    my $table_name = ( $client_ref->get_client_type() eq 'ortho' ? 'properties' : 'profile' );
#    $self->add_statement(
#        "UPDATE ".$client_ref->get_db_name().".$table_name SET SVal=NULL " .
#            "WHERE PKey=".$self->{'dbh'}->quote($param)." AND SVal=" .
#            $self->{'dbh'}->quote($guid),
#    );
#    $self->{'affected_clients'}{ $client_ref->get_db_name() } = 1;
#}
#
#sub get_srm_resources {
#    my ($self) = @_;
#
#    return $self->{'dbh'}->selectall_arrayref(
#        "SELECT id, container, path_from, date FROM srm.resources",
#        { 'Slice' => {} },
#    );
#}
#
#sub get_client_property {
#    my ($self, $client_ref, $param) = @_;
#
#    $self->{'dbh'}->do("USE ".$client_ref->get_db_name());
#    my $client_prop = Sesame::Unified::ClientProperties->new(
#        $client_ref->get_client_type(),
#        $self->{'dbh'},
#    );
#
#    return $client_prop->get_property($param);
#}
#
#sub client_by_db {
#    my ($self, $db) = @_;
#
#    return Sesame::Unified::Client->new('db_name', $db);
#}

sub get_client_data_by_db {
    my ($self, $db) = @_;

    require ClientData::DB::Sesame_4;
    return ClientData::DB::Sesame_4->new($self, $db);
}

#sub get_clients {
#    my ($self) = @_;
#
#    return Sesame::Unified::Client->get_all_clients();
#}

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

sub is_client_exists {
    my ($self, $db_name) = @_;

	my $db = $self->{'dbh'}->selectrow_array("SHOW DATABASES LIKE ?", undef, $db_name);
    return defined $db && $db eq $db_name;
}



1;