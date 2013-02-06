## $Id$
package ClientData::DB::Sesame_5;

use strict;
use warnings;

use File::Spec;

use base qw( ClientData::DB );

sub new {
	my ($class, $data_source, $db_name, $dbh, $force_type) = @_;

	if (defined $force_type && $force_type ne 'sesame') {
		die "unknown client type [$force_type] forced in 5.0 for [$db_name]";
	}
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

sub phone_is_used {
	my ($self, $phone) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM phone WHERE number=? AND client_id=?",
        undef,
        $phone,
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

sub get_appointments_by_pid {
    my ($self, $pid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Date(datetime) AS Date, MAX(ifnull(state='confirmed',0)) AS Confirm, duration_minutes AS Duration FROM appointment WHERE patient_id=? GROUP BY Date ORDER BY Date",
		{ 'Slice' => {} },
        $pid,
    );
}

sub get_accounts_by_pid {
	my ($self, $pid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
		"SELECT a.id AS AccountId, insurance_contract_id AS IId ".
		"FROM account a ".
		"LEFT JOIN responsible_patient rp ON (a.responsible_patient_id=rp.id AND a.client_id=rp.client_id) ".
		"WHERE rp.patient_id=? AND rp.client_id=?",
		{ 'Slice' => {} },
		$pid,
		$self->{'client_id'},
    );
}

sub get_ledgers_by_account_date_interval {
    my ($self, $account, $from, $to) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT datetime AS DateTime, amount AS Amount, description AS Description, type AS Type FROM ledger WHERE account_id=? AND datetime BETWEEN CONCAT(?, ' 00:00:00') AND CONCAT(?, ' 00:00:00') - INTERVAL 1 SECOND ORDER BY datetime",
		{ 'Slice' => {} },
        $account,
        $from,
        $to,
    );
}

sub get_sent_emails_by_pid_type {
	my ($self, $pid, $type) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        $self->_get_email_sent_mail_log_select()." WHERE sml_mail_type=? AND visitor_id=? ORDER BY sml_date",
		{ 'Slice' => {} },
        $type,
        $pid,
    );
}

sub count_emails_by_pid {
	my ($self, $pid) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
		"SELECT count(*) FROM email WHERE visitor_id=? AND client_id=?",
		undef,
		$pid,
        $self->{'client_id'},
	);
}

sub get_complete_cc_payments {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Time AS DateTime, Provider, FName, LName, Email, Comment, Amount, PaymentType AS Type FROM opse_payment_log WHERE client_id=? AND if(Provider='PRI', TResult='OK', Provider='Malse') ORDER BY Time",
		{ 'Slice' => {} },
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

sub get_all_sent_emails_with_body {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_email_sent_mail_log_select()." LEFT JOIN visitor v ON (v.id=l.visitor_id) WHERE v.client_id=? AND NOT sml_body LIKE 'file://%'",
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

    return 'id, pms_id, address_id, address_id_in_pms, type, first_name AS FName, last_name AS LName, birthday AS BDate, blocked, blocked_source, privacy, password, no_email, active, active AS Active, active_in_pms';
}

sub get_all_patients {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id AS PId, ".$self->_get_visitor_columns()." FROM visitor WHERE type='patient' AND client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub get_ledgers_date_interval {
    my ($self) = @_;

    return $self->{'dbh'}->selectrow_hashref(
        "SELECT DATE(MAX(datetime)) as max, DATE(MIN(datetime)) as min FROM ledger WHERE client_id=?",
        undef,
        $self->{'client_id'},
    );
}

sub count_sent_emails_by_type {
	my ($self, $type) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM email_contact_log l ".
        "LEFT JOIN visitor v ON (v.id=l.visitor_id) ".
        "WHERE v.client_id=? AND clog_mail_type=? AND clog_code=?",
        undef,
        $self->{'client_id'},
		$type,
		1,
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

sub get_visitor_ids_by_email {
    my ($self, $email) = @_;

	return $self->{'dbh'}->selectcol_arrayref(
        "SELECT visitor_id FROM email WHERE email=? AND client_id=?",
		undef,
		$email,
		$self->{'client_id'},
    );
}

sub get_patients_by_pms_id {
    my ($self, $visitor_pms_id) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id AS VisitorId, ".$self->_get_visitor_columns()." FROM visitor WHERE type=? AND pms_id=? AND client_id=?",
		{ 'Slice' => {} },
		"patient",
		$visitor_pms_id,
		$self->{'client_id'},
    );
}

sub get_responsibles_by_pms_id {
    my ($self, $visitor_pms_id) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id AS VisitorId, ".$self->_get_visitor_columns()." FROM visitor WHERE type=? AND pms_id=? AND client_id=?",
		{ 'Slice' => {} },
		"responsible",
		$visitor_pms_id,
		$self->{'client_id'},
    );
}

sub get_responsible_by_id {
    my ($self, $id) = @_;

    return $self->{'dbh'}->selectrow_hashref(
        "SELECT id AS RId, ".$self->_get_visitor_columns()." FROM visitor WHERE type=? AND id=? AND client_id=?",
		undef,
		"responsible",
		$id,
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

sub get_invisalign_client_ids {
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

sub get_invisalign_patients_by_patient_id {
	my ($self, $patient_id) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT ".$self->_get_invisalign_patient_columns()." FROM invisalign_patient WHERE patient_id=?",
		{ 'Slice' => {} },
		$patient_id,
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
	my @params = (
		$visitor_id, $email, $belongs_to, $name,
		$source, $deleted,
		$self->{'client_id'},
    );
	$self->_do_query(<<'SQL', \@params);
INSERT INTO email
	(visitor_id, email, date, responsible_type, relative_name,
	source, deleted, deleted_datetime, deleted_source,
	client_id)
VALUES
	(%s, %s, NOW(), %s, %s,
	%s, %s, NULL, NULL,
	%s)
SQL
}

sub add_phone {
    my ($self, $visitor_id, $number, $type, $sms_active, $voice_active, $source, $entry_datetime) = @_;

	my @params = (
		$visitor_id, $number, $type,
		$sms_active, $voice_active,
		$source, $entry_datetime,
		$self->{'client_id'},
    );
	$self->_do_query(<<'SQL', \@params);
INSERT INTO phone (
	visitor_id, number, type,
	sms_active, voice_active,
	source, entry_datetime,
	client_id, ext, comment,
	deleted, deleted_datetime, deleted_source
)
VALUES
	(%s, %s, %s,
	%s, %s,
	%s, %s,
	%s, '', '',
	'false', null, null)
SQL
}


sub get_all_si_images {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT ImageId, PatId, FileName, TypeId, TimePoint FROM si_image WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub get_si_images {
    my ($self, $pat_id) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT ImageId, PatId, FileName, TypeId, TimePoint FROM si_image WHERE client_id=? AND PatId=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
		$pat_id,
    );
}

sub get_si_patient_timepoint_link {
    my ($self, $pat_id) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT TpNum AS TimePoint, date AS Date, TpName AS TimePointName FROM si_patient_timepoint_link WHERE client_id=? AND PatId=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
		$pat_id,
    );
}


sub get_all_si_image_types {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT TypeId, TypeName FROM si_image_type WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub add_si_image_type {
	my ($self, $type_id, $name) = @_;

	return $self->_do_query("INSERT INTO si_image_type (TypeId, client_id, TypeName, " .
		"Position, FlipH, FlipV, Date, hidden, TypeOrder) VALUES(%s, %s, %s, 0, 0, 0, NOW(), 0, 0)",
		[ $type_id, $self->{'client_id'}, $name ]
	);
}

sub delete_si_image {
	my ($self, $id) = @_;

	return $self->_do_query(
		"DELETE FROM si_image WHERE ImageId=%s AND client_id=%s LIMIT 1",
		[ $id, $self->{'client_id'} ]
	);
}

sub update_si_image_time_point {
	my ($self, $id, $time_point, $comment) = @_;

	return $self->_do_query(
		"UPDATE si_image SET TimePoint=%s WHERE ImageId=%s AND client_id=%s LIMIT 1",
		[ $time_point, $id, $self->{'client_id'} ], 
		$comment
	);
}

sub insert_si_patient_timepoint_link {
	my ($self, $pat_id, $time_point, $time_point_name, $comment) = @_;

	return $self->_do_query(
		"INSERT INTO si_patient_timepoint_link (PatId, client_id, TpNum, date, TpName) VALUES (%s, %s, %s, NULL, %s)",
		[ $pat_id, $self->{'client_id'}, $time_point, $time_point_name ], 
		$comment
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
	$self->_do_query(<<'SQL', \@params);
INSERT INTO hhf_applications (
	client_id, filldate, fname,
	lname, birthdate, note,
	signature, body
)
VALUES (%s, %s, %s,  %s, %s, %s,  %s, %s)
SQL
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
	$self->_do_query(<<'SQL', \@params);
INSERT INTO hhf_settings (
	client_id,
	PKey, Type, SVal,
	IVal, RVal, DVal
)
VALUES (%s,  %s, %s, %s,  %s, %s, %s)
SQL
}

sub add_hhf_client_setting {
	my ($self, $params) = @_;

	my @params = ($self->{'client_id'}, @$params{'guid', 'install_date'});
	$self->_do_query(<<'SQL', \@params);
INSERT INTO hhf_client_settings (client_id, guid, install_date)
VALUES (%s, %s, %s)
SQL
}

sub add_hhf_template {
	my ($self, $body) = @_;

	if (ref($body) eq 'HASH') {
		$body = $body->{'body'};
	}
	my @params = ($self->{'client_id'}, $body);
	$self->_do_query(<<'SQL', \@params);
INSERT INTO hhf_templates (client_id, body) VALUES (%s, %s)
SQL
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

	my @params = (
		$self->{'client_id'},
		@$params{
			'is_enabled', 'type',
			'subject', 'body', 'response_options',
			'design_id', 'image_guid', 'image_title'
		},
	);
	return $self->_do_query(<<'SQL', \@params);
INSERT INTO email_reminder_settings
	(client_id, is_enabled, type,
	subject, body, response_options,
	design_id, image_guid, image_title)
VALUES (%s,%s,%s, %s,%s,%s, %s,%s,%s)
SQL
}

sub update_email_reminder_setting_body {
    my ($self, $id, $new_body, $comment) = @_;
	
	return $self->_do_query(<<'SQL', [ $new_body, $self->{'client_id'}, $id ], $comment);
UPDATE email_reminder_settings SET body=%s WHERE client_id=%s AND id=%s LIMIT 1
SQL
}

sub delete_email_reminder_setting_body {
    my ($self, $id, $comment) = @_;
	
	return $self->_do_query(<<'SQL', [ $self->{'client_id'}, $id ], $comment);
DELETE FROM email_reminder_settings WHERE client_id=%s AND id=%s LIMIT 1
SQL
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

	my @params = (
		$self->get_username(),
		@$params{
			'id', 'date',
			'path_from', 'type', 'description',
		},
	);
	return $self->_do_query(<<'SQL', \@params);
INSERT INTO srm_resource
	(container, id, date,
	path_from, type, description)
VALUES (%s,%s,%s, %s,%s,%s)
SQL
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

sub delete_invisalign_patient_by_id {
	my ($self, $id, $comment) = @_;

	$self->_do_query("DELETE FROM invisalign_patient WHERE id=%s LIMIT 1", [$id], $comment);
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

sub delete_invisalign_patient_by_invisalign_client {
	my ($self, $case_number, $invisalign_client_id) = @_;

	$self->_do_query(
		"DELETE FROM invisalign_case_process_patient WHERE case_number=%s AND invisalign_client_id=%s",
		[$case_number, $invisalign_client_id],
	);
	$self->_do_query(
		"DELETE FROM invisalign_patient WHERE case_num=%s AND invisalign_client_id=%s",
		[$case_number, $invisalign_client_id],
	);
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

sub get_invisalign_processing_patients_by_client_id {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT case_number, fname, lname, vip_patient_id, processed, store_date, post_date, adf_file, linked, invisalign_client_id" .
			" FROM invisalign_case_process_patient WHERE client_id = ?",
		{ 'Slice' => {} },
		$self->{'client_id'},
	);
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

sub file_path_for_srm {
	my ($self, $file) = @_;

	return File::Spec->join(
    	$ENV{'SESAME_COMMON'},
		'srm',
		$self->get_username(),
		$file
    );
}

sub file_path_for_newsletter {
	my ($self, $hash) = @_;

	return File::Spec->join(
    	$ENV{'SESAME_COMMON'},
		'members',
		$self->get_username(),
		'common',
		'news',
		$hash,
		'index.html',
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

sub get_all_newsletters {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        <<'SQL',
SELECT id, letter_hash, is_send, send_to, dt, recipient_count
FROM ppn_email_queue
WHERE client_id=?
SQL
		{ 'Slice' => {} },
		$self->{'client_id'},
    );
}

sub delete_phone {
	my ($self, $id, $visitor_id) = @_;

	$self->_do_query(<<'SQL', [ $id, $visitor_id, $self->{'client_id'} ]);
DELETE FROM phone WHERE id=%s AND visitor_id=%s AND client_id=%s LIMIT 1
SQL
}

sub delete_email {
	my ($self, $id, $visitor_id) = @_;

	$self->_do_query(<<'SQL', [ $id, $visitor_id, $self->{'client_id'} ]);
DELETE FROM email WHERE id=%s AND visitor_id=%s AND client_id=%s LIMIT 1
SQL
}

sub set_sent_email_body {
	my ($self, $id, $body) = @_;

	$self->_do_query(
		"UPDATE email_sent_mail_log SET sml_body=%s WHERE id=%s LIMIT 1",
		[
			$body,
			$id,
		],
	);
}

sub set_visitor_address_id {
	my ($self, $visitor_id, $address_id) = @_;

	$self->_do_query(
		"UPDATE visitor SET address_id=%s WHERE id=%s AND client_id=%s LIMIT 1",
		[
			$address_id,
			$visitor_id,
			$self->{'client_id'},
		],
	);

#	my @params = ($address_id, $visitor_id, $self->{'client_id'});
#	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
#UPDATE visitor SET address_id=%s WHERE id=%s AND client_id=%s LIMIT 1
#SQL
#	$sql =~ s/\r?\n/ /g;
#	$sql =~ s/\s+/ /g;
#
#	unless ($self->{'data_source'}->is_read_only()) {
#		$self->{'dbh'}->do($sql);
#	}
#	$self->{'data_source'}->add_statement($sql);
}

sub set_sms_active_for_phone_number {
	my ($self, $visitor_id, $phone_number, $sms_active) = @_;

	$self->_do_query(
		"UPDATE phone SET sms_active=%s WHERE visitor_id=%s AND number=%s AND client_id=%s LIMIT 1",
		[
			$sms_active,
			$visitor_id,
			$phone_number,
			$self->{'client_id'},
		],
	);

#	my @params = ($sms_active, $visitor_id, $phone_number, $self->{'client_id'});
#	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
#UPDATE phone SET sms_active=%s WHERE visitor_id=%s AND number=%s AND client_id=%s LIMIT 1
#SQL
#	$sql =~ s/\r?\n/ /g;
#	$sql =~ s/\s+/ /g;
#
#	unless ($self->{'data_source'}->is_read_only()) {
#		$self->{'dbh'}->do($sql);
#	}
#	$self->{'data_source'}->add_statement($sql);
}

sub set_visitor_password_by_id {
	my ($self, $password, $visitor_id) = @_;

	$self->_do_query(
		"UPDATE visitor SET password=%s WHERE id=%s AND client_id=%s LIMIT 1",
		[
			$password,
			$visitor_id,
			$self->{'client_id'},
		],
	);

#	my @params = ($password, $visitor_id, $self->{'client_id'});
#	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
#UPDATE visitor SET password=%s WHERE id=%s AND client_id=%s LIMIT 1
#SQL
#	$sql =~ s/\r?\n/ /g;
#	$sql =~ s/\s+/ /g;
#
#	unless ($self->{'data_source'}->is_read_only()) {
#		$self->{'dbh'}->do($sql);
#	}
#	$self->{'data_source'}->add_statement($sql);
}

sub set_email_address_by_id {
	my ($self, $id, $email) = @_;

	$self->_do_query(
		"UPDATE email SET email=%s WHERE id=%s AND client_id=%s LIMIT 1",
		[
			$email,
			$id,
			$self->{'client_id'},
		],
	);
}

sub dump_table_data {
	my ($self, $table_name, $table_id, $columns, $where, $logger) = @_;

	my $escaped_table_name = '`'.$table_name.'`';
	my $sql = "SELECT ".join(", ", $table_id, @$columns)." FROM ".$escaped_table_name." WHERE client_id=? AND NOT ISNULL(".$table_id.")";
	if (defined $where) {
		$sql .= " AND ".$where;
	}
	my $qr = $self->{'dbh'}->prepare($sql);
	$qr->execute($self->{'client_id'});
	while (my $r = $qr->fetchrow_hashref()) {
		my $update_sql = "UPDATE ".$escaped_table_name .
			" SET ". join(', ', map {'`'.$_.'`='.$self->{'dbh'}->quote( $r->{$_} )} @$columns) .
			" WHERE client_id=".$self->{'dbh'}->quote( $self->{'client_id'} ) .
			" AND ".$table_id."=".$self->{'dbh'}->quote( $r->{$table_id} );
		if (defined $where) {
			$update_sql .= ' AND '.$where;
		}
		$update_sql .= ' LIMIT 1';
		$self->{'data_source'}->add_statement($update_sql);
		if ($logger) {
			$logger->printf_slow("save data for %s.%s='%s'", $table_name, $table_id, $r->{$table_id});
			$logger->register_category("restore $table_name");
		}
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

sub get_all_offices {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT id, address_id, name, pms_id FROM office WHERE client_id=?",
		{ 'Slice' => {} },
		$self->get_id(),
    );
}

sub file_path_for_google_map {
	my ($self, $address_id) = @_;

	return File::Spec->join(
    	$ENV{'SESAME_COMMON'},
    	'google-maps',
    	$address_id.'.gif',
    );
}

sub delete_google_map {
	my ($self, $address_id) = @_;

	$self->_do_query(<<'SQL', [ $address_id ]);
DELETE FROM google_map WHERE address_id=%s LIMIT 1
SQL
}

sub get_sent_mail_log_by_visitor_id {
	my ($self, $visitor_id) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_email_sent_mail_log_select()." WHERE visitor_id=?",
		{ 'Slice' => {} },
        $visitor_id,
	);
}

sub _get_email_sent_mail_log_select {
	my ($self) = @_;

	return "SELECT l.id, l.visitor_id, sml_email AS Email, sml_name AS Name, sml_mail_type, sml_date AS DateTime, sml_mail_id, sml_body AS Body, sml_body_hash, contact_log_id FROM email_sent_mail_log l";
}

sub get_appointment_schedule_by_reminder_type {
	my ($self, $reminder_type) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT id, weekday as appointment_week_day, send_offset, send_time, send_offset_unit FROM appointment_reminder_schedule WHERE client_id=? AND reminder_type=?",
		{ 'Slice' => {} },
        $self->{'client_id'},
        $reminder_type,
	);
}

sub add_appointment_schedule {
	my ($self, $reminder_type, $appointment_week_day, $send_offset, $send_offset_unit, $send_time) = @_;

	$self->_do_query(
		"INSERT INTO appointment_reminder_schedule (client_id, weekday, send_offset, send_offset_unit, send_time, reminder_type) VALUES (%s, %s, %s, %s, %s, %s)",
		[
			$self->{'client_id'},
			$appointment_week_day,
			$send_offset,
			$send_offset_unit,
			$send_time,
			$reminder_type,
		],
	);
}

sub delete_appointment_schedule {
	my ($self, $reminder_type, $appointment_week_day, $send_offset, $schedule_id) = @_;

	$self->_do_query(
		"DELETE FROM appointment_reminder_schedule WHERE ".
			"client_id=%s AND weekday=%s AND send_offset=%s AND reminder_type=%s".
			(defined $schedule_id ? ' AND id=%s' :''),
		[
			$self->{'client_id'},
			$appointment_week_day,
			$send_offset,
			$reminder_type,
			(defined $schedule_id ?
				( $schedule_id ):
				()
			),
		],
	);
}

sub get_all_holiday_settings {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT hds_id AS id, hd_id AS holiday_id, hdc_id AS holiday_card_id, ".
			"hds_subject AS subject, hds_optional_text AS optional_text, ".
			"hds_status AS is_enabled, hds_date AS date ".
			"FROM holiday_settings WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
	);
}

sub get_all_holidays {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT hd_id AS id, hd_name AS name, hd_subject AS subject, hd_date AS date ".
		"FROM holidays",
		{ 'Slice' => {} },
	);
}

sub update_holiday_setting_date {
    my ($self, $id, $date) = @_;
	
	$self->_do_query(
		"UPDATE holiday_settings SET hds_date=%s WHERE client_id=%s AND hds_id=%s LIMIT 1",
		[
			$date,
			$self->{'client_id'},
			$id,
		],
	);
}

sub delete_holiday_setting {
	my ($self, $id) = @_;

	$self->_do_query(
		"DELETE FROM holiday_settings WHERE client_id=%s AND hds_id=%s",
		[
			$self->{'client_id'},
			$id,
		],
	);

}

sub is_ccp_enabled {
	my ($self) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
		"SELECT count(*) FROM opse_client_settings WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
	);
}

sub get_voice_reminder_settings {
    my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT id, client_id, name, template, voice_menu, is_enabled, ".
			"sending_template, transfer_phone, reminder_type ".
			"FROM voice_reminder_settings WHERE client_id=?",
		{ 'Slice' => {} },
		$self->{'client_id'},
	);
}

sub delete_voice_setting {
    my ($self, $id) = @_;

	$self->_do_query(
		"DELETE FROM voice_reminder_settings WHERE client_id=%s AND id=%s LIMIT 1",
		[
			$self->{'client_id'},
			$id,
		],
	);
}

sub add_voice_setting {
    my ($self, $reminder_type, $name, $is_enabled) = @_;
	
	$self->_do_query(
		"INSERT INTO voice_reminder_settings (client_id, name, is_enabled, reminder_type) VALUES(%s, %s, %s, %s)",
		[
			$self->{'client_id'},
			$name,
			$is_enabled,
			$reminder_type,
		],
	);
}

1;
