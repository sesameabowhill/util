## $Id$
package DataSource::DB::Sesame_4;

use strict;
use warnings;

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

sub get_client_data_by_db {
    my ($self, $db, $force_type) = @_;

    require ClientData::DB::Sesame_4;
    return ClientData::DB::Sesame_4->new($self, $db, $self->{'dbh'}, $force_type);
}

sub get_client_data_by_id {
    my ($self, $id) = @_;

    require ClientData::DB::Sesame_4;
    return ClientData::DB::Sesame_4->new_by_id($self, $id, $self->{'dbh'});
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

sub is_database_exists {
    my ($self, $db_name) = @_;

	my $db = $self->{'dbh'}->selectrow_array("SHOW DATABASES LIKE ?", undef, $db_name);
    return defined $db && $db eq $db_name;
}

sub get_database_by_username {
	my ($self, $username) = @_;

	my $db_name = $self->{'dbh'}->selectrow_array(
		"SELECT cl_mysql FROM sesameweb.clients WHERE cl_username=?",
		undef,
		$username,
	);
	unless ($db_name) {
		$db_name = $self->{'dbh'}->selectrow_array(
			"SELECT cl_mysql FROM dentists.clients WHERE cl_mysql=?",
			undef,
			$username,
		);
	}
	return $db_name;
}

sub get_all_case_numbers {
	my ($self) = @_;

	my @case_numbers = (
		$self->{'dbh'}->selectcol_arrayref(<<'SQL'),
SELECT case_number FROM invisalign.icp_patients
SQL
		$self->{'dbh'}->selectcol_arrayref(<<'SQL'),
SELECT case_num FROM invisalign.Patient
SQL
		$self->{'dbh'}->selectcol_arrayref(<<'SQL'),
SELECT case_number FROM dentists.icp_patients
SQL
		$self->{'dbh'}->selectcol_arrayref(<<'SQL'),
SELECT case_num FROM dentists.inv_patients
SQL
	);
	my %numbers;
	for my $arr (@case_numbers) {
		for my $number (@$arr) {
			$numbers{$number} = 1;
		}
	}
	return [ keys %numbers ];
}


sub get_invisalign_client_ids_by_case_number {
	my ($self, $case_number) = @_;

	my $ortho_ids = $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT CONCAT('oi', client_id) FROM invisalign.Patient WHERE case_num=?
SQL
	my $dental_ids = $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT CONCAT('di', client_id) FROM dentists.inv_patients WHERE case_num=?
SQL
	return [ @$ortho_ids, @$dental_ids ];
}

sub get_invisalign_processing_client_ids_by_case_number {
	my ($self, $case_number) = @_;

	my $ortho_ids = $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT CONCAT('oi', doctor_id) FROM invisalign.icp_patients WHERE case_number=?
SQL
	my $dental_ids = $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT CONCAT('di', doctor_id) FROM dentists.icp_patients WHERE case_number=?
SQL
	return [ @$ortho_ids, @$dental_ids ];
}

sub get_client_id_by_invisalign_id {
	my ($self, $invisalign_id) = @_;

	my ($sql, $invisalign_client_id) = _invisalign_query_by_id(
		$invisalign_id,
		"SELECT CONCAT('o', sesame_cl_id) FROM invisalign.Client WHERE client_id=?",
		"SELECT CONCAT('d', dental_cl_id) FROM dentists.inv_clients WHERE id=?",
	);
	return scalar $self->{'dbh'}->selectrow_array($sql, undef, $invisalign_client_id);
}

sub _invisalign_query_by_id {
	my ($id, $ortho_query, $dental_query) = @_;

	if ($id =~ m/^oi(\d+)$/) {
		return ($ortho_query, $1);
	}
	elsif ($id =~ m/^di(\d+)$/) {
		return ($dental_query, $1);
	}
	else {
		die "invalid invisalign client id [$id]";
	}
}

sub get_all_clincheck_files {
	my ($self) = @_;

	my $ortho_files = $self->_get_all_clincheck_files(
		File::Spec->join(
	    	$ENV{'SESAME_WEB'},
	    	'invisalign_cases',
	    )
	);
	my $dental_files = $self->_get_all_clincheck_files(
		File::Spec->join(
	    	$ENV{'SESAME_WEB'},
	    	'dental_cases',
	    )
	);
	return [ @$ortho_files, @$dental_files ];
}


#Patient.case_num
#Patient.client_id
#Patient.pat_id
#inv_patients.case_num
#inv_patients.client_id
#inv_patients.pat_id

#icp_patients.case_number
#icp_patients.doctor_id


#Client.client_id
#icp_doctors.id


#delete from icp_patients where doctor_id in (148);
#delete from icp_doctors where id         in (148);
#delete from inv_clients where id         in (148);
#delete from inv_patients where client_id in (148);

#delete from icp_patients where doctor_id in (148);
#delete from icp_doctors where id         in (148);
#delete from Client where client_id       in (148);
#delete from Patient where client_id      in (148);


#delete from icp_patients where case_number in (70102);
#delete from inv_patients where case_num    in (70102);

#select * from invisalign.icp_patients where case_number in ();
#select * from dentists.inv_patients where      case_num in ();
#select * from dentists.icp_patients where   case_number in ();

1;