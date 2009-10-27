package ClientData::DB::Dental;

use strict;

use base qw( ClientData::DB );

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

sub get_appointments {
    my ($self, $pid, $order, $number) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT Date, MAX(ifnull(Status='confirmed',0)) AS Confirm, Duration FROM AppointmentsHistory WHERE PId=? AND Why='moved' GROUP BY Date ORDER BY Date $order LIMIT ?",
		{ 'Slice' => {} },
        $pid,
        $number,
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

1;