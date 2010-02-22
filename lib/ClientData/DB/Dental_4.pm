package ClientData::DB::Dental_4;

use strict;

use base qw( ClientData::DB::Sesame_4 );

sub get_full_type {
	my ($class) = @_;

	return 'dental';
}

sub get_appointment_columns {
    my ($self) = @_;

    return [ 'Date', 'Confirm', 'Duration' ];
}

sub get_patients {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, FName, LName, BDate, Active<>0 AS Active FROM Patients ORDER BY 3,2",
		{ 'Slice' => {} },
    );
}

sub get_addresses_by_pid {
	my ($self, $pid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, RId, StreetAddress AS Street, City, State, Zipcode AS Zip FROM Addresses WHERE PId=?",
		{ 'Slice' => {} },
		$pid,
    );
}

sub get_appointments_by_pid {
    my ($self, $pid, $order, $number) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Date, MAX(ifnull(Status='confirmed',0)) AS Confirm, Duration FROM AppointmentsHistory WHERE PId=? AND Why='moved' GROUP BY Date ORDER BY Date $order LIMIT ?",
		{ 'Slice' => {} },
        $pid,
        $number,
    );
}

sub get_appointments_by_date_interval {
    my ($self, $start_date, $end_date) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, Date, ifnull(Status='confirmed', 0) AS Confirm, Duration FROM AppointmentsHistory WHERE Why='moved' AND Date BETWEEN ? AND ? ORDER BY Date",
		{ 'Slice' => {} },
        $start_date,
        $end_date,
    );
}

sub get_number_of_appointments_per_date {
	my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Date, count(*) as Count FROM AppointmentsHistory WHERE Why='moved' GROUP BY Date",
		{ 'Slice' => {} },
    );
}

sub get_visited_offices {
	my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT PId, OfficeId, count(*) AS Count FROM AppointmentsHistory GROUP BY 1, 2",
		{ 'Slice' => {} },
    );
}

sub get_offices {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT OfficeId, Name AS OfficeName, CONCAT(StreetAddress, ' ', City, ', ', State, ' ', Zipcode) AS OfficeLocation FROM Offices",
		{ 'Slice' => {} },
	);
}

sub get_patient_appointment {
    my ($self, $pid, $date) = @_;

    my $select_str = "MAX(ifnull(Status='confirmed',0)) AS Confirm";
    my $appointment = $self->{'dbh'}->selectrow_hashref(
        "SELECT $select_str FROM AppointmentsHistory WHERE PId=? AND Date=? AND Why='moved'",
		undef,
        $pid,
        $date,
    );
    unless (defined $appointment) {
        $appointment = $self->{'dbh'}->selectrow_hashref(
            "SELECT $select_str FROM Appointments WHERE PId=? AND Date=?",
            undef,
            $pid,
            $date,
        );
    }
    if (defined $appointment) {
        $appointment->{'NotifiedApp'} = $self->{'dbh'}->selectrow_array(
            "SELECT count(*) FROM contact_log WHERE clog_pat_id=? AND clog_tdate=? AND clog_mail_type=0 AND clog_mail_id<>-1",
            undef,
            $pid,
            $date,
        );
        $appointment->{'NotifiedNoshow'} = $self->{'dbh'}->selectrow_array(
            "SELECT count(*) FROM contact_log WHERE clog_pat_id=? AND clog_tdate=? AND clog_mail_type=3 AND clog_mail_id<>-1",
            undef,
            $pid,
            $date,
        );
        $appointment->{'NotifiedApp'} ||= undef;
        $appointment->{'NotifiedNoshow'} ||= undef;
    }

    return $appointment;
}


sub is_using_insurance {
    my ($self, $pid) = @_;

    return $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM Ledgers WHERE PId=? AND Type IN ('I', 'IP')",
        undef,
        $pid,
    );
}

sub email_exists_by_pid {
    my ($self, $email, $pid) = @_;

    my ($count) = $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM Mails WHERE PId=? AND Address=?",
        { 'Slice' => {} },
        $pid,
        $email,
    );
    return $count;
}

sub email_exists_by_rid {
    my ($self, $email, $rid) = @_;

    my ($count) = $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM Mails WHERE RId=? AND Address=?",
        { 'Slice' => {} },
        $rid,
        $email,
    );
    return $count;
}

sub count_emails_by_pid {
	my ($self, $pid) = @_;

    my ($count) = $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM Mails WHERE PId=?",
        { 'Slice' => {} },
        $pid,
    );
    return $count;
}


sub email_is_used {
    my ($self, $email) = @_;

    return scalar $self->{'dbh'}->selectrow_array(
        "SELECT count(*) FROM Mails WHERE Address=?",
        undef,
        $email,
    );
}


sub get_patient_ids_by_name {
    my ($self, $fname, $lname) = @_;

    return _search_by_name('PId, RId', 'Patients', $fname, $lname);
}

sub get_responsible_ids_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_search_by_name('RId', 'Responsibles', $fname, $lname);
}

sub get_patients_by_responsible {
    my ($self, $rid) = @_;

    return $self->{'dbh'}->selectcol_arrayref(
        "SELECT PId FROM Patients WHERE RId=?",
        undef,
        $rid
    );
}

sub add_email {
    my ($self, $pid, $rid, $email) = @_;

    my $insert_q = $self->prepare("INSERT INTO Mails (PId, RId, Address, EntryDate, Status, FName, LName, Source) VALUES (?,?,?,NOW(),0,NULL,NULL,4)");
    $insert_q->execute($pid, $rid, $email);
}

sub get_profile_value {
	my ($self, $key) = @_;

	return $self->_get_profile_value($key, 'profile', '');
}

sub get_sales_resources {
    my ($self) = @_;

    return $self->{'dbh'}->selectrow_hashref(
        "SELECT phone, address, city, metro_area, state, zip_code, respondents, reference, quote, doctors_count FROM dentists.sales_resource WHERE cl_id=?",
        undef,
        $self->{'client'}{'id'},
    );
}

sub _get_id {
	my ($self) = @_;

	return 'd'.$self->{'client'}{'id'};
}

sub get_all_ppn_emails {
	my ($self) = @_;

	return $self->_get_all_ppn_emails('newsletters_dental.email_queue');
}


sub _get_invisalign_patient_columns {
	my ($self) = @_;

	return 'case_num AS case_number, client_id AS invisalign_client_id, fname, lname, post_date, start_treatment AS start_date, retire_treatment AS retire_date, stages, img_available, pat_id AS patient_id, refine, deleted';
}

sub get_all_invisalign_patients {
	my ($self) = @_;

	my $inv_client_ids = $self->_get_invisalign_client_ids();

	if (@$inv_client_ids) {
		return $self->{'dbh'}->selectall_arrayref(
	        "SELECT ".$self->_get_invisalign_patient_columns()." FROM dentists.inv_patients
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
				"SELECT id FROM dentists.inv_clients WHERE dental_cl_id=?",
				undef,
				$self->{'client'}{'id'},
			);
		}
	);
}

sub file_path_for_invisalign_comment {
	my ($self, $invisalign_client_id, $case_number) = @_;

	return File::Spec->join(
    	$ENV{'SESAME_WEB'},
    	'dental_cases',
    	$invisalign_client_id,
    	$case_number.'.txt',
    );
}

sub delete_invisalign_patient {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_quotes_ids();

	if ($inv_client_ids) {
		my $sql = "DELETE FROM dentists.inv_patients WHERE client_id IN (" .
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
		my $sql = "DELETE FROM dentists.icp_patients WHERE doctor_id IN (" .
			$inv_client_ids . ") AND case_number=" . $self->{'dbh'}->quote($case_number);

		$self->{'data_source'}->add_statement($sql);
		unless ($self->{'data_source'}->is_read_only()) {
			$self->{'dbh'}->do($sql);
		}
	}
}

1;