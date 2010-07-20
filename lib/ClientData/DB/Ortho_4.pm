## $Id$
package ClientData::DB::Ortho_4;

use base qw( ClientData::DB::Sesame_4 );

sub get_reverse_remap {
	my ($self, $table_id, $id) = @_;

	return $self->{'dbh'}->selectrow_array(
		"SELECT orig_id FROM ".$self->{'db_name'}.".remap WHERE id=? AND table_id=?",
		undef,
		$id,
		$table_id,
	);
}

sub add_remap {
	my ($self, $table_id, $id, $orig_id) = @_;

	$self->{'dbh'}->do(
		"INSERT INTO ".$self->{'db_name'}.".remap (table_id, id, orig_id) VALUES (?, ?, ?)",
		undef,
		$table_id,
		$id,
		$orig_id,
	);
}

sub get_all_remap_tables {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT id, name FROM sesameweb.remap_tables",
		{ 'Slice' => {} },
	);
}

sub get_all_ids_by_table_name {
	my ($self, $table_name) = @_;

	my %known_ids = (
		'procedures' => {
			'table' => 'procedures',
			'id'    => 'ProcId',
		},
	);
	if (exists $known_ids{$table_name}) {
		return $self->{'dbh'}->selectcol_arrayref(
			"SELECT ".$known_ids{$table_name}{'id'}." FROM ".$self->{'db_name'}.".".$known_ids{$table_name}{'table'},
		);
	}
	else {
		die "unknown table [$table_name]";
	}
}

sub get_appointments_by_pid {
    my ($self, $pid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, Date, MIN(Time) AS Time, OfficeID, ProcID, LastNotified, Notified, Registered, Removed, Why, Status, StatusChanged FROM ".$self->{'db_name'}.".ah_app_history WHERE PId=? AND Why='moved' GROUP BY Date ORDER BY Date",
		{ 'Slice' => {} },
        $pid,
    );
}

sub get_number_of_appointments_per_date {
	my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Date, count(*) as Count FROM ".$self->{'db_name'}.".ah_app_history WHERE Why='moved' GROUP BY Date",
		{ 'Slice' => {} },
    );
}

sub get_ledgers_date_interval {
    my ($self) = @_;

    return $self->{'dbh'}->selectrow_hashref(
        "SELECT LEFT(MAX(DateTime), 10) as max, LEFT(MIN(DateTime), 10) as min FROM ".$self->{'db_name'}.".ledgers",
    );
}

sub get_ledgers_by_account_date_interval {
    my ($self, $account, $from, $to) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT DateTime, Amount, Description, Type FROM ".$self->{'db_name'}.".ledgers WHERE AccountId=? AND DateTime BETWEEN CONCAT(?, ' 00:00:00') AND CONCAT(?, ' 00:00:00') - INTERVAL 1 SECOND ORDER BY DateTime",
		{ 'Slice' => {} },
        $account,
        $from,
        $to,
    );
}



sub get_emails_by_responsible {
	my ($self, $rid) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select()." WHERE ml_resp_id=?",
		{ 'Slice' => {} },
		$rid,
	);
}

sub get_emails_by_address {
	my ($self, $email) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select()." WHERE ml_email=?",
		{ 'Slice' => {} },
		$email,
	);
}

sub get_moved_emails_by_address {
	my ($self, $email) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select(1)." WHERE ml_email=?",
		{ 'Slice' => {} },
		$email,
	);
}

sub get_emails_by_pid {
	my ($self, $pid) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select()." WHERE ml_pat_id=?",
		{ 'Slice' => {} },
		$pid,
	);
}

sub get_all_emails {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select(),
		{ 'Slice' => {} },
	);
}

sub get_all_moved_emails {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_emails_select(1),
		{ 'Slice' => {} },
	);
}

sub _get_emails_select {
	my ($self, $is_moved) = @_;

	my $moved_fields = ( $is_moved ? <<SQL : '');
	ml_moved_date AS MovedDate,
	ml_moved_source AS MovedSource,
SQL
	my $table = ( $is_moved ? $self->{'db_name'}.".moved_mails" : $self->{'db_name'}.".maillist");
	return <<SQL;
SELECT
$moved_fields
	ml_id AS id,
	ml_resp_id AS RId,
	ml_pat_id AS PId,
	ml_belongsto AS BelongsTo,
	ml_email AS Email,
	ml_name AS Name,
    ml_date AS Date,
	ml_status AS Status,
	ml_source AS Source,
	'false' AS Deleted
FROM $table
SQL
}

sub get_responsibles {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT RId, FName, LName FROM ".$self->{'db_name'}.".responsibles",
		{ 'Slice' => {} },
	);
}

sub get_responsible_by_id {
	my ($self, $rid) = @_;

	return $self->{'dbh'}->selectrow_hashref(
		"SELECT RId, FName, LName FROM ".$self->{'db_name'}.".responsibles WHERE RId=?",
		undef,
		$rid,
	);
}

sub email_exists_by_pid {
    my ($self, $email, $pid) = @_;

    my ($count) = $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM ".$self->{'db_name'}.".maillist WHERE ml_pat_id=? AND ml_email=?",
        { 'Slice' => {} },
        $pid,
        $email,
    );
    return $count;
}

sub email_exists_by_rid {
    my ($self, $email, $rid) = @_;

    my ($count) = $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM ".$self->{'db_name'}.".maillist WHERE ml_resp_id=? AND ml_email=?",
        { 'Slice' => {} },
        $rid,
        $email,
    );
    return $count;
}

sub email_is_used {
    my ($self, $email) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM ".$self->{'db_name'}.".maillist WHERE ml_email=?",
        undef,
        $email,
    );
}

sub get_patients_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_search_by_name(
    	'PId, FName, LName, BDate, Phone, Status',
    	$self->{'db_name'}.".patients",
    	$fname,
    	$lname,
    );
}

sub get_patients_by_name_and_ids {
    my ($self, $fname, $lname, $ids) = @_;

    return $self->_search_by_name(
    	'PId, FName, LName, BDate, Phone, Status',
    	$self->{'db_name'}.".patients",
    	$fname,
    	$lname,
    	"PId IN (".join(', ', map {$self->{'dbh'}->quote($_)} @$ids).")",
    );
}

sub get_patients_by_name_and_phone_and_ids {
    my ($self, $fname, $lname, $phone, $ids) = @_;

    return $self->_search_by_name(
    	'PId, FName, LName, BDate, Phone, Status',
    	$self->{'db_name'}.".patients",
    	$fname,
    	$lname,
    	"Phone LIKE ".$self->{'dbh'}->quote($self->_string_to_like($phone)).
    	"AND PId IN (".join(', ', map {$self->{'dbh'}->quote($_)} @$ids).")",
    );
}

sub get_responsible_ids_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_search_by_name('RId', 'responsibles', $fname, $lname);
}

sub get_patient_by_id {
	my ($self, $pid) = @_;

	return $self->{'dbh'}->selectrow_hashref(
		"SELECT PId, FName, LName, BDate, Phone, Status FROM ".$self->{'db_name'}.".patients WHERE PId=?",
		undef,
		$pid,
	);
}

sub get_patients {
    my ($self) = @_;

	warn "depricated function [get_patients]";
	return $self->get_all_patients();
}

sub get_all_patients {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, FName, LName, BDate, Phone, Status AS Active FROM ".$self->{'db_name'}.".patients ORDER BY 3,2",
		{ 'Slice' => {} },
    );
}

sub get_addresses_by_pid {
	my ($self, $pid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, Zip, State, City, Street FROM ".$self->{'db_name'}.".addresses WHERE PId=?",
		{ 'Slice' => {} },
		$pid,
    );
}

sub get_all_accounts {
	my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
		"SELECT AccountId, PId, RId, IId, CntTotal, InitFee, InitFeeMult, CDue , CntBalance, NextPmntDate, NextPmntAmount FROM ".$self->{'db_name'}.".accounts",
		{ 'Slice' => {} },
    );
}

sub get_accounts_by_pid {
	my ($self, $pid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
		"SELECT AccountId, PId, RId, IId, CntTotal, InitFee, InitFeeMult, CDue , CntBalance, NextPmntDate, NextPmntAmount FROM ".$self->{'db_name'}.".accounts WHERE PId=?",
		{ 'Slice' => {} },
		$pid,
    );
}


sub get_visited_offices {
	my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, OfficeId, count(*) AS Count FROM ".$self->{'db_name'}.".ah_app_history GROUP BY 1, 2",
		{ 'Slice' => {} },
    );
}

sub get_offices {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT OfficeId, OfficeName, OfficeLocation FROM ".$self->{'db_name'}.".offices",
		{ 'Slice' => {} },
	);
}

sub get_patient_ids_by_responsible {
    my ($self, $rid) = @_;

    return $self->{'dbh'}->selectcol_arrayref(
        "SELECT PId FROM ".$self->{'db_name'}.".prlinks WHERE RId=?",
        undef,
        $rid,
    );
}

sub get_responsible_ids_by_patient {
    my ($self, $pid) = @_;

    return $self->{'dbh'}->selectcol_arrayref(
        "SELECT RId FROM ".$self->{'db_name'}.".prlinks WHERE PId=?",
        undef,
        $pid,
    );
}

sub add_email {
    my ($self, $pid, $rid, $email, $belongs_to, $name, $status, $source) = @_;

	my @params = map {$self->{'dbh'}->quote($_)} (
		$rid,    $pid,   $belongs_to,
    	$email,  $name,  $status,
    	$source
    );
	my $sql = sprintf(<<'SQL', $self->{'db_name'}, @params);
INSERT INTO %s.maillist
	(ml_resp_id, ml_pat_id, ml_belongsto,
	 ml_email, ml_name, ml_date,
	 ml_status,  ml_source)
VALUES
	(%s, %s, %s,
	%s, %s, NOW(),
	%s, %s)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;
	$self->{'dbh'}->do($sql);
	$self->{'data_source'}->add_statement($sql);
}

sub get_feature_status {
	my ($self, $feature) = @_;

	my %feature_ids = (
		'ccp' => 7,
	);
	unless (exists $feature_ids{$feature}) {
		die "unknown feature [$feature]";
	}

	my ($type, $id) = ($self->_get_id() =~ m/^(\w)(\d+)$/);

	return scalar $self->{'dbh'}->selectrow_array(
		"SELECT status FROM sesameweb.feature_settings WHERE cl_id=? AND feature_id=?",
		undef,
		$id,
		$feature_ids{$feature},
	);
}

sub get_unique_ledgers_description_by_type {
    my ($self, $type) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Description, count(*) AS Count FROM ".$self->{'db_name'}.".ledgers WHERE Type=? GROUP BY 1",
		{ 'Slice' => {} },
        $type,
    );

}

sub get_profile_value {
	my ($self, $key) = @_;

	return $self->_get_profile_value($key, $self->{'db_name'}.'.properties', '');
}

#sub get_sales_resources {
#	select * from client_profiles where name='doctors count'
#}


sub get_sales_resources {
    my ($self) = @_;

	my %key_remap = (
		'doctors count' => 'doctors_count',
		'metro area'    => 'metro_area',
		'phone number'  => 'phone',
	);

    my $rows = $self->{'dbh'}->selectall_arrayref(
        "SELECT name, value FROM sesameweb.client_profiles WHERE cl_id=?",
		{ 'Slice' => {} },
        $self->{'client'}{'id'},
    );
    my %result;
    for my $row (@$rows) {
    	if (exists $key_remap{ $row->{'name'} }) {
    		$result{ $key_remap{ $row->{'name'} } } = $row->{'value'};
    	}
    	else {
    		$result{ $row->{'name'} } = $row->{'value'};
    	}
    }
    return \%result;
}

sub get_id {
	my ($self) = @_;

	return 'o'.$self->{'client'}{'id'};
}

sub get_all_ppn_emails {
	my ($self) = @_;

	return $self->_get_all_ppn_emails('newsletters_ortho.email_queue');
}

sub _get_invisalign_patient_columns {
	my ($self) = @_;

	return 'case_num AS case_number, client_id AS invisalign_client_id, fname, lname, post_date, request_date AS start_date, retire_date, upper_stages AS stages, img_available, pat_id AS patient_id, refine';
}

sub get_all_invisalign_patients {
	my ($self) = @_;

	my $inv_client_ids = $self->_get_invisalign_client_ids();

	if (@$inv_client_ids) {
		return $self->{'dbh'}->selectall_arrayref(
	        "SELECT ".$self->_get_invisalign_patient_columns()." FROM invisalign.Patient
	        WHERE client_id IN (".join(
	        	", ",
	        	map { $self->{'dbh'}->quote($_) } @$inv_client_ids
	        ).")",
			{ 'Slice' => {} },
	    );
	}
	else {
		return [];
	}
}


sub _get_invisalign_client_ids {
	my ($self) = @_;

	return $self->get_cached_data(
		'_invisalign_client_ids',
		sub {
			return $self->{'dbh'}->selectcol_arrayref(
				"SELECT client_id FROM invisalign.Client WHERE sesame_cl_id=?",
				undef,
				$self->{'client'}{'id'},
			);
		}
	);
}

sub file_path_for_clinchecks {
	my ($self, $invisalign_client_id) = @_;

	$invisalign_client_id = _get_true_invisalign_client_id($invisalign_client_id);
	return File::Spec->join(
    	$ENV{'SESAME_WEB'},
    	'invisalign_cases',
    	$invisalign_client_id,
    );
}

sub _get_true_invisalign_client_id {
	my ($id) = @_;

	if ($id =~ m/^(?:oi)?(\d+)$/) {
		return $1;
	}
	else {
		die "invalid invisalign client id [$id]";
	}
}


sub delete_invisalign_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();

	if ($inv_client_ids) {
		my $sql = "DELETE FROM invisalign.Patient WHERE client_id IN (" .
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
		my $sql = "DELETE FROM invisalign.icp_patients WHERE doctor_id IN (" .
			$inv_client_ids . ") AND case_number=" . $self->{'dbh'}->quote($case_number);

		$self->{'data_source'}->add_statement($sql);
		unless ($self->{'data_source'}->is_read_only()) {
			$self->{'dbh'}->do($sql);
		}
	}
}

sub get_invisalign_patients_by_name {
	my ($self, $fname, $lname) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();

	if ($inv_client_ids) {
		return $self->_search_with_fields_by_name(
	    	$self->_get_invisalign_patient_columns(),
	    	'fname',
	    	'lname',
	    	'invisalign.Patient',
	    	$fname,
	    	$lname,
	    	"client_id IN (".$inv_client_ids.")",
	    );
	}
	else {
		return [];
	}
}

sub set_sesame_patient_for_invisalign_patient {
	my ($self, $case_number, $sesame_patient_id) = @_;

	my $update_sql = "UPDATE invisalign.Patient SET pat_id=" . $self->{'dbh'}->quote($sesame_patient_id) .
		" WHERE case_num=" . $self->{'dbh'}->quote($case_number);

	$self->{'data_source'}->add_statement($update_sql);
	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($update_sql);
	}
}

sub get_invisalign_processing_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();
	if ($inv_client_ids) {
		return $self->{'dbh'}->selectrow_hashref(
			"SELECT case_number, fname, lname, patient_id AS vip_patient_id, processed, store_date, post_date, adf_file, linked" .
				" FROM invisalign.icp_patients WHERE doctor_id IN (" . $inv_client_ids .
				") AND case_number=" . $self->{'dbh'}->quote($case_number)
		);
	}
	else {
		return undef;
	}
}

sub get_invisalign_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();
	if ($inv_client_ids) {
		return $self->{'dbh'}->selectrow_hashref(
			"SELECT " . $self->_get_invisalign_patient_columns() .
				" FROM invisalign.Patient WHERE client_id IN (" . $inv_client_ids .
				") AND case_num=" . $self->{'dbh'}->quote($case_number)
		);
	}
	else {
		return undef;
	}
}


sub set_invisalign_client_id_for_invisalign_patient {
	my ($self, $case_number, $invisalign_client_id) = @_;

	my $update_icp_sql = "UPDATE invisalign.icp_patients SET " .
		"doctor_id=" . $self->{'dbh'}->quote($invisalign_client_id) .
		" WHERE case_number=" . $self->{'dbh'}->quote($case_number);
	my $update_sql = "UPDATE invisalign.Patient SET client_id=" . $self->{'dbh'}->quote($invisalign_client_id) .
		" WHERE case_num=" . $self->{'dbh'}->quote($case_number);

	$self->{'data_source'}->add_statement($update_icp_sql);
	$self->{'data_source'}->add_statement($update_sql);
	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($update_icp_sql);
		$self->{'dbh'}->do($update_sql);
	}
}

sub set_invisalign_processing_patient_processed {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();
	if ($inv_client_ids) {
		my $sql = "UPDATE invisalign.icp_patients SET processed=1 WHERE doctor_id IN (" .
			$inv_client_ids . ") AND case_number=" . $self->{'dbh'}->quote($case_number);

		$self->{'data_source'}->add_statement($sql);
		unless ($self->{'data_source'}->is_read_only()) {
			$self->{'dbh'}->do($sql);
		}
	}
}

sub add_invisaling_patient {
	my ($self, $case_number, $invisalign_client_id, $params) = @_;

	my @params = (
		$case_number, $invisalign_client_id,
		@$params{'fname', 'lname', 'post_date', 'start_date', 'transfer_date', 'retire_date', 'stages'},
	);
	my $sql = sprintf(<<'SQL', map { $self->{'dbh'}->quote($_) } @params);
INSERT INTO invisalign.Patient (
	case_num, client_id,
	fname, lname, post_date, request_date, transfer_date, retire_date, upper_stages,
	img_available, pat_id, refine, email, lower_stages, tray_num, done_by
) VALUES (
	%s, %s,
	%s, %s, %s, %s, %s, %s, %s,
	'flu', NULL, 0, NULL, 0, '', NULL
)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;

	unless ($self->{'data_source'}->is_read_only()) {
		$self->{'dbh'}->do($sql);
	}
	$self->{'data_source'}->add_statement($sql);

}


1;