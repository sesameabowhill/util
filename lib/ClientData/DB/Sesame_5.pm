## $Id$
package ClientData::DB::Sesame_5;

use strict;
use warnings;

use File::Spec;

use base qw( ClientData::DB );

sub new {
	my ($class, $data_source, $db_name, $dbh) = @_;

	return $class->_new_by($data_source, 'cl_username', $db_name, $dbh);
}

sub new_by_id {
	my ($class, $data_source, $id, $dbh) = @_;

	return $class->_new_by($data_source, 'id', $id, $dbh);
}

sub _new_by {
	my ($class, $data_source, $column_name, $db_name, $dbh) = @_;

	my $self = $class->SUPER::new($data_source, $db_name);
	$self->{'client'} = _get_client_params($dbh, $column_name, $db_name);
	$self->{'client_id'} = $self->get_id();
	$self->{'dbh'} = $dbh;
	return $self;
}

sub _get_client_params {
	my($dbh, $columns_name, $db_name) = @_;

	$dbh->selectrow_hashref(<<SQL, undef, $db_name);
SELECT
	id, cl_pathw AS web_folder, cl_status AS status,
	cl_timezone AS timezone, cl_username AS username, cl_pathw AS web_folder
FROM client
WHERE $columns_name=?
SQL
}

sub get_db_name {
	my ($self) = @_;

	return $self->get_username();
}

sub get_username {
	my ($self) = @_;

	return $self->{'client'}{'username'};
}

sub is_active {
	my ($self) = @_;

	return $self->{'client'}{'status'} == 1;
}

sub get_id {
	my ($self) = @_;

	return $self->{'client'}{'id'};
}

sub get_full_type {
	my ($class) = @_;

	return 'sesame';
}


sub email_is_used {
	my ($self, $email) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM email e WHERE e.email=? AND e.client_id=?",
        undef,
        $email,
        $self->{'client_id'},
    );
}

sub get_emails_by_pid {
	my ($self, $pid) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select()." FROM email WHERE visitor_id=? AND client_id=?",
		{ 'Slice' => {} },
		$pid,
        $self->{'client_id'},
	);
}

sub get_emails_by_responsible {
	my ($self, $rid) = @_;

	return $self->get_emails_by_pid($rid);
}

sub get_all_emails {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select().", visitor_id AS VisitorId, visitor_id, pms_id FROM email WHERE client_id=?",
		{ 'Slice' => {} },
        $self->{'client_id'},
	);
}


sub _get_emails_select {
	my ($self) = @_;

	return <<SQL;
SELECT
	id,
	email AS Email,
	responsible_type AS BelongsTo,
	relative_name AS Name,
    date AS Date,
	source AS Source,
	deleted AS Deleted
SQL
}

sub get_patients_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_get_visitors_by_name(
    	'id AS PId',
    	$fname,
    	$lname,
    	'type="patient"',
    );
}

sub get_patients_by_name_and_birth {
    my ($self, $fname, $lname, $bdate) = @_;

    return $self->_get_visitors_by_name(
    	'id AS PId',
    	$fname,
    	$lname,
    	'birthday='.$self->{'dbh'}->quote($bdate).' AND type="patient"',
    );
}

sub get_patients_by_name_and_pms_id {
    my ($self, $fname, $lname, $visitor_pms_id) = @_;

    return $self->_get_visitors_by_name(
    	'id AS PId',
    	$fname,
    	$lname,
    	'pms_id='.$self->{'dbh'}->quote($visitor_pms_id).' AND type="patient"',
    );
}

sub get_responsibles_by_name_and_pms_id {
    my ($self, $fname, $lname, $visitor_pms_id) = @_;

    return $self->_get_visitors_by_name(
    	'id AS RId',
    	$fname,
    	$lname,
    	'pms_id='.$self->{'dbh'}->quote($visitor_pms_id).' AND type="responsible"',
    );
}

sub get_patients_by_name_and_ids {
    my ($self, $fname, $lname, $ids) = @_;

    return $self->_get_visitors_by_name(
    	'id AS PId',
    	$fname,
    	$lname,
    	'type="patient" AND id IN ('.join(', ', map {$self->{'dbh'}->quote($_)} @$ids).')',
    );
}

sub get_responsibles_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_get_visitors_by_name(
    	'id AS RId',
    	$fname,
    	$lname,
    	'type="responsible"',
    );
}

sub _get_visitors_by_name {
    my ($self, $id_column, $fname, $lname, $where) = @_;

    return $self->_search_with_fields_by_name(
    	$id_column.', '.$self->_get_visitor_columns(),
    	'first_name',
    	'last_name',
    	'visitor',
    	$fname,
    	$lname,
    	'client_id='.$self->{'dbh'}->quote($self->{'client_id'}).' AND '.$where,
    );
}

sub _get_visitor_columns {
    my ($self) = @_;

    return 'id, pms_id, address_id, address_id_in_pms, type, first_name AS FName, last_name AS LName, birthday AS BDate, blocked, blocked_source, privacy, password, no_email, active, active_in_pms';
}

sub get_all_patients {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id AS PId, ".$self->_get_visitor_columns()." FROM visitor WHERE type='patient' AND client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub get_all_visitors {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT ".$self->_get_visitor_columns()." FROM visitor WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub get_patient_by_id {
    my ($self, $pid) = @_;

	return $self->{'dbh'}->selectrow_hashref(
        "SELECT id AS PId, ".$self->_get_visitor_columns()." FROM visitor WHERE type='patient' AND id=? AND client_id=?",
		{ 'Slice' => {} },
		$pid,
		$self->{'client_id'},
    );
}

sub get_address_by_id {
    my ($self, $address_id) = @_;

	return $self->{'dbh'}->selectrow_hashref(
        "SELECT id, pms_id, street, city, state, zip, country FROM address WHERE id=? AND client_id=?",
		{ 'Slice' => {} },
		$address_id,
		$self->{'client_id'},
    );
}

sub get_visitor_by_id {
    my ($self, $visitor_id) = @_;

	return $self->{'dbh'}->selectrow_hashref(
        "SELECT id AS VisitorId, ".$self->_get_visitor_columns()." FROM visitor WHERE id=? AND client_id=?",
		{ 'Slice' => {} },
		$visitor_id,
		$self->{'client_id'},
    );
}

sub get_patient_ids_by_responsible {
    my ($self, $rid) = @_;

    return $self->{'dbh'}->selectcol_arrayref(
        "SELECT patient_id FROM responsible_patient WHERE responsible_id=?",
        undef,
        $rid,
    );
}

sub get_all_responsibles {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id AS RId, ".$self->_get_visitor_columns()." FROM visitor WHERE type='responsible' AND client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub _get_invisalign_client_ids {
	my ($self) = @_;

	return $self->get_cached_data(
		'_invisalign_client_ids',
		sub {
			return $self->{'dbh'}->selectcol_arrayref(
				"SELECT id FROM invisalign_client WHERE client_id=?",
				undef,
				$self->{'client_id'},
			);
		}
	);
}

sub get_invisalign_patients_by_name {
	my ($self, $fname, $lname) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();

	if ($inv_client_ids) {
		return $self->_search_with_fields_by_name(
	    	$self->_get_invisalign_patient_columns(),
	    	'fname',
	    	'lname',
	    	'invisalign_patient',
	    	$fname,
	    	$lname,
	    	"invisalign_client_id IN (".$inv_client_ids.")",
	    );
	}
	else {
		return [];
	}
}

sub get_all_invisalign_patients {
	my ($self) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();

	if ($inv_client_ids) {
		return $self->{'dbh'}->selectall_arrayref(
	        "SELECT ".$self->_get_invisalign_patient_columns()." FROM invisalign_patient
	        WHERE invisalign_client_id IN (".$inv_client_ids.")",
			{ 'Slice' => {} },
	    );
	}
	else {
		return [];
	}
}

sub set_sesame_patient_for_invisalign_patient {
	my ($self, $case_number, $sesame_patient_id) = @_;

	my $update_sql = "UPDATE invisalign_patient SET patient_id=" . $self->{'dbh'}->quote($sesame_patient_id) .
		" WHERE case_num=" . $self->{'dbh'}->quote($case_number);

	$self->{'data_source'}->add_statement($update_sql);
	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($update_sql);
	}
}

sub _get_invisalign_patient_columns {
	my ($self) = @_;

	return 'case_num AS case_number, invisalign_client_id, fname, lname, post_date, start_date, transfer_date, retire_date, stages, img_available, patient_id, refine, deleted';
}

sub add_email {
    my ($self, $visitor_id, $email, $belongs_to, $name, $source, $deleted) = @_;

	$deleted ||= 'false';
	my @params = map {$self->{'dbh'}->quote($_)} (
		$visitor_id, $email, $belongs_to, $name,
		$source, $deleted,
		$self->{'client_id'},
    );
	my $sql = sprintf(<<'SQL', @params);
INSERT INTO email
	(visitor_id, email, date, responsible_type, relative_name,
	source, deleted, deleted_datetime, deleted_source,
	client_id)
VALUES
	(%s, %s, NOW(), %s, %s,
	%s, %s, NULL, NULL,
	%s)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;
	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}


sub get_all_si_images {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT ImageId, PatId, FileName FROM si_image WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub get_all_si_patients {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT PatId, FName, LName, BDate, Link FROM si_patient WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub link_si_patient {
	my ($self, $sesame_patient_id, $si_patient_id) = @_;

	my $insert_sql = "INSERT INTO si_patient_link (patient_id, si_patient_id, client_id) " .
		"VALUES (" . $self->{'dbh'}->quote($sesame_patient_id) .
		", " . $self->{'dbh'}->quote($si_patient_id) .
		", " . $self->{'dbh'}->quote($self->{'client_id'}) . ")";
	my $update_sql = "UPDATE si_patient SET Link=1 WHERE PatId=" .
		$self->{'dbh'}->quote($si_patient_id) . " AND client_id=" .
		$self->{'dbh'}->quote($self->{'client_id'}) . " LIMIT 1";

	$self->{'data_source'}->add_statement($insert_sql);
	$self->{'data_source'}->add_statement($update_sql);
	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($insert_sql);
		$self->{'dbh'}->do($update_sql);
	}

}

sub get_patients_linked_to_si_patient {
	my ($self, $pid) = @_;

	return $self->{'dbh'}->selectcol_arrayref(
        "SELECT patient_id FROM si_patient_link WHERE client_id=? AND si_patient_id=?",
		undef,
		$self->{'client_id'},
		$pid,
    );
}

sub get_si_patient_by_id {
	my ($self, $pat_id) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT FName, LName, BDate, Link FROM si_patient WHERE PatId=? AND client_id=?",
		{ 'Slice' => {} },
		$pat_id,
		$self->{'client_id'},
    )->[0];
}

sub get_hhf_id {
	my ($self) = @_;


	return $self->get_cached_data(
		'_hhf_id',
		sub {
			return $self->get_profile_value('HHF->GUID');
		}
	);
#	return scalar $self->{'dbh'}->selectrow_array(
#		"SELECT guid FROM hhf_client_settings WHERE client_id=?",
#		undef,
#		$self->{'client_id'},
#	);
}

sub get_profile_value {
	my ($self, $key) = @_;

	return $self->_get_profile_value(
		$key,
		'client_setting',
		' AND client_id=' . $self->{'dbh'}->quote( $self->{'client_id'} ),
	);
}

sub set_profile_value {
	my ($self, $key, $value, $type) = @_;

	my $type_id = $self->_get_profile_type_id_by_column_name($type);
	my $update_sql = sprintf(
		'INSERT INTO client_setting (client_id, PKey, Type, %s) VALUES (%s, %s, %s, %s) ON DUPLICATE KEY UPDATE %s=%s, Type=%s',
		$type,
		map({ $self->{'dbh'}->quote($_) } ( $self->{'client_id'}, $key, $type_id, $value )),
		$type,
		map({ $self->{'dbh'}->quote($_) } ( $value, $type_id )),
	);
	if ($self->{'data_source'}->is_read_only()) {
		$self->{'data_source'}->add_statement($update_sql);
	} else {
		$self->{'dbh'}->do($update_sql);
	}
}

sub get_hhf_settings {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT PKey, Type, SVal, IVal, RVal, DVal FROM hhf_settings WHERE client_id=?",
		{ 'Slice' => {} },
		$self->get_id(),
    );
}

sub get_hhf_templates {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT body, 1 AS body_exists FROM hhf_templates WHERE client_id=?",
		{ 'Slice' => {} },
		$self->get_id(),
    );
}

sub get_all_hhf_forms {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, filldate, fname, lname, birthdate, note, signature, body FROM hhf_applications WHERE client_id=?",
		{ 'Slice' => {} },
		$self->get_id(),
    );
}

sub get_hhf_client_settings {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT guid, install_date FROM hhf_client_settings WHERE client_id=?",
		{ 'Slice' => {} },
		$self->get_id(),
    );
}

sub add_hhf_form {
	my ($self, $filldate, $fname, $lname, $birthdate, $note, $signature, $body) = @_;

	if (ref($filldate) eq 'HASH') {
		($filldate, $fname, $lname, $birthdate, $note, $signature, $body) =
			@$filldate{'filldate', 'fname', 'lname', 'birthdate', 'note', 'signature', 'body'};
	}
	my @params = (
		$self->{'client_id'},  $filldate, $fname,
		$lname,  $birthdate, $note,
		$signature, $body,
	);
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
INSERT INTO hhf_applications (
	client_id, filldate, fname,
	lname, birthdate, note,
	signature, body
)
VALUES (%s, %s, %s,  %s, %s, %s,  %s, %s)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}

sub add_hhf_setting {
	my ($self, $params) = @_;

	my @params = (
		$self->{'client_id'},
		@$params{
			'PKey', 'Type', 'SVal',
			'IVal', 'RVal', 'DVal'
		},
	);
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
INSERT INTO hhf_settings (
	client_id,
	PKey, Type, SVal,
	IVal, RVal, DVal
)
VALUES (%s,  %s, %s, %s,  %s, %s, %s)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}

sub add_hhf_client_setting {
	my ($self, $params) = @_;

	my @params = ($self->{'client_id'}, @$params{'guid', 'install_date'});
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
INSERT INTO hhf_client_settings (client_id, guid, install_date)
VALUES (%s, %s, %s)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}

sub add_hhf_template {
	my ($self, $body) = @_;

	if (ref($body) eq 'HASH') {
		$body = $body->{'body'};
	}

	my @params = ($self->{'client_id'}, $body);
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
INSERT INTO hhf_templates (client_id, body) VALUES (%s, %s)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}


sub get_email_reminder_settings {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT id, is_enabled, type, subject, body, response_options, design_id, image_guid, image_title FROM email_reminder_settings WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
	);
}


sub add_new_reminder_setting {
	my ($self, $params) = @_;

	$self->{'dbh'}->do(
		<<SQL,
INSERT INTO email_reminder_settings
	(client_id, is_enabled, type,
	subject, body, response_options,
	design_id, image_guid, image_title)
VALUES (?,?,?, ?,?,?, ?,?,?)
SQL
		undef,
		$self->{'client_id'},
		@$params{
			'is_enabled', 'type',
			'subject', 'body', 'response_options',
			'design_id', 'image_guid', 'image_title'
		},
	);
	return $self->{'dbh'}->{'mysql_insertid'};
}


sub get_all_srm_resources {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, container, date, path_from, type, description FROM srm_resource WHERE container=?",
		{ 'Slice' => {} },
		$self->get_username(),
    );
}

sub add_new_srm_resource {
	my ($self, $params) = @_;

	$self->{'dbh'}->do(
		<<SQL,
INSERT INTO srm_resource
	(container, id, date,
	path_from, type, description)
VALUES (?,?,?, ?,?,?)
SQL
		undef,
		$self->get_username(),
		@$params{
			'id', 'date',
			'path_from', 'type', 'description',
		},
	);
	return $self->{'dbh'}->{'mysql_insertid'};
}

sub delete_invisalign_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();

	if ($inv_client_ids) {
		my $sql = "DELETE FROM invisalign_patient WHERE invisalign_client_id IN (" .
			$inv_client_ids . ") AND case_num=" . $self->{'dbh'}->quote($case_number);

		$self->{'data_source'}->add_statement($sql);
		unless ($self->{'data_source'}->is_read_only()) {
			$self->{'dbh'}->do($sql);
		}
	}
}

sub delete_invisalign_processing_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();

	if ($inv_client_ids) {
		my $sql = "DELETE FROM invisalign_case_process_patient WHERE invisalign_client_id IN (" .
			$inv_client_ids . ") AND case_number=" . $self->{'dbh'}->quote($case_number);

		$self->{'data_source'}->add_statement($sql);
		unless ($self->{'data_source'}->is_read_only()) {
			$self->{'dbh'}->do($sql);
		}
	}
}

sub set_invisalign_processing_patient_processed {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();
	if ($inv_client_ids) {
		my $sql = "UPDATE invisalign_case_process_patient SET processed=1 WHERE invisalign_client_id IN (" .
			$inv_client_ids . ") AND case_number=" . $self->{'dbh'}->quote($case_number);

		$self->{'data_source'}->add_statement($sql);
		unless ($self->{'data_source'}->is_read_only()) {
			$self->{'dbh'}->do($sql);
		}
	}
}

sub get_invisalign_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();
	if ($inv_client_ids) {
		return $self->{'dbh'}->selectrow_hashref(
			"SELECT " . $self->_get_invisalign_patient_columns() .
				" FROM invisalign_patient WHERE invisalign_client_id IN (" . $inv_client_ids .
				") AND case_num=" . $self->{'dbh'}->quote($case_number)
		);
	}
	else {
		return undef;
	}
}

sub get_invisalign_processing_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();
	if ($inv_client_ids) {
		return $self->{'dbh'}->selectrow_hashref(
			"SELECT case_number, fname, lname, vip_patient_id, processed, store_date, post_date, adf_file, linked" .
				" FROM invisalign_case_process_patient WHERE invisalign_client_id IN (" . $inv_client_ids .
				") AND case_number=" . $self->{'dbh'}->quote($case_number)
		);
	}
	else {
		return undef;
	}
}

sub get_invisalign_client_by_shared_invisalign_client {
	my ($self, $shared_invisalign_client_id) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
		<<'SQL',
SELECT id
FROM invisalign_client
WHERE client_id=? AND inv_uname IN (
	SELECT inv_uname FROM invisalign_client WHERE id=?
)
SQL
		undef,
		$self->{'client_id'},
		$shared_invisalign_client_id,
	);
}


sub set_invisalign_client_id_for_invisalign_patient {
	my ($self, $case_number, $invisalign_client_id) = @_;

	my $update_icp_sql = "UPDATE invisalign_case_process_patient SET " .
		"invisalign_client_id=" . $self->{'dbh'}->quote($invisalign_client_id) . ", " .
		"client_id=" . $self->{'dbh'}->quote( $self->{'client_id'} ) .
		" WHERE case_number=" . $self->{'dbh'}->quote($case_number);
	my $update_sql = "UPDATE invisalign_patient SET invisalign_client_id=" . $self->{'dbh'}->quote($invisalign_client_id) .
		" WHERE case_num=" . $self->{'dbh'}->quote($case_number);

	$self->{'data_source'}->add_statement($update_icp_sql);
	$self->{'data_source'}->add_statement($update_sql);
	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($update_icp_sql);
		$self->{'dbh'}->do($update_sql);
	}
}

sub add_invisaling_patient {
	my ($self, $case_number, $invisalign_client_id, $params) = @_;

	my @params = (
		$case_number, $invisalign_client_id,
		@$params{'fname', 'lname', 'post_date', 'start_date', 'transfer_date', 'retire_date', 'stages'},
	);
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
INSERT INTO invisalign_patient (
	case_num, invisalign_client_id,
	fname, lname, post_date, start_date, transfer_date, retire_date, stages,
	img_available, patient_id, refine, deleted
) VALUES (
	%s, %s,
	%s, %s, %s, %s, %s, %s, %s,
	'flu', NULL, 0, NULL
)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);

}


sub file_path_for_si_image {
	my ($self, $file_name) = @_;

	return File::Spec->join(
    	$ENV{'SESAME_COMMON'},
    	'image-systems',
    	$self->get_username(),
    	'si',
    	'images',
    	$file_name,
    );
}

sub file_path_for_clinchecks {
	my ($self, $invisalign_client_id) = @_;

	return File::Spec->join(
    	$ENV{'SESAME_COMMON'},
    	'invisalign-cases',
    	$invisalign_client_id,
    );
}

sub get_all_phones {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        <<'SQL',
SELECT
	id, pms_id, link_id, visitor_id, number, ext, comment, type,
	sms_active='true' AS sms_active, voice_active='true' AS voice_active,
	source, deleted, deleted_datetime, deleted_source, entry_datetime
FROM phone
WHERE client_id=?
SQL
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub delete_phone {
	my ($self, $id, $visitor_id) = @_;

	my @params = ($id, $visitor_id, $self->{'client_id'});
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
DELETE FROM phone WHERE id=%s AND visitor_id=%s AND client_id=%s LIMIT 1
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}

sub delete_email {
	my ($self, $id, $visitor_id) = @_;

	my @params = ($id, $visitor_id, $self->{'client_id'});
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
DELETE FROM email WHERE id=%s AND visitor_id=%s AND client_id=%s LIMIT 1
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}

sub set_visitor_address_id {
	my ($self, $visitor_id, $address_id) = @_;

	my @params = ($address_id, $visitor_id, $self->{'client_id'});
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
UPDATE visitor SET address_id=%s WHERE id=%s AND client_id=%s LIMIT 1
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);
}

sub dump_table_data {
	my ($self, $table_name, $table_id, $columns, $where) = @_;

	$table_name = '`'.$table_name.'`';
	my $sql = "SELECT ".join(", ", $table_id, @$columns)." FROM ".$table_name." WHERE client_id=? AND NOT ISNULL(".$table_id.")";
	if (defined $where) {
		$sql .= " AND ".$where;
	}
	my $qr = $self->{'dbh'}->prepare($sql);
	$qr->execute($self->{'client_id'});
	while (my $r = $qr->fetchrow_hashref()) {
		my $update_sql = "UPDATE ".$table_name .
			" SET ". join(', ', map {'`'.$_.'`='.$self->{'dbh'}->quote( $r->{$_} )} @$columns) .
			" WHERE client_id=".$self->{'dbh'}->quote( $self->{'client_id'} ) .
			" AND ".$table_id."=".$self->{'dbh'}->quote( $r->{$table_id} );
		if (defined $where) {
			$update_sql .= ' AND '.$where;
		}
		$update_sql .= ' LIMIT 1';
		$self->{'data_source'}->add_statement($update_sql);
	}
}

sub get_clients_who_share_invisalign_accounts {
	my ($self) = @_;

	my $client_ids = $self->{'dbh'}->selectcol_arrayref(
		<<'SQL',
SELECT client_id
FROM invisalign_client
WHERE inv_uname IN (
	SELECT inv_uname
	FROM invisalign_client
	WHERE client_id=?
) and client_id<>?
SQL
		undef,
		$self->{'client_id'},
		$self->{'client_id'},
	);
	return [ map {ref($self)->new_by_id($self->{'data_source'}, $_, $self->{'dbh'})} @$client_ids ];
}

1;