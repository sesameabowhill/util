## $Id$
package ClientData::DB::Ortho;

use base qw( ClientData::DB );

sub get_reverse_remap {
	my ($self, $table_id, $id) = @_;
	
	return $self->{'dbh'}->selectrow_array(
		"SELECT orig_id FROM remap WHERE id=? AND table_id=?",
		undef,
		$id,
		$table_id,
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

sub _get_emails_select {
	my ($self) = @_;

	return <<'SQL',
SELECT 
	ml_id AS id, 
	ml_resp_id AS RId, 
	ml_pat_id AS PId, 
	ml_belongsto AS BelongsTo, 
	ml_email AS Email, 
	ml_name AS Name,
    ml_date AS Date, 
	ml_status AS Status,   
	ml_source AS Source
FROM maillist 
SQL
}

sub get_responsibles {
	my ($self) = @_;
	
	return $self->{'dbh'}->selectall_arrayref(
		"SELECT RId, FName, LName FROM responsibles",
		{ 'Slice' => {} },
	);
}

sub get_responsible_by_id {
	my ($self, $rid) = @_;
	
	return $self->{'dbh'}->selectrow_hashref(
		"SELECT RId, FName, LName FROM responsibles WHERE RId=?",
		undef,
		$rid,
	);
}

sub email_exists_by_pid {
    my ($self, $email, $pid) = @_;

    my ($count) = $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM maillist WHERE ml_pat_id=? AND ml_email=?",
        { 'Slice' => {} },
        $pid,
        $email,
    );
    return $count;
}

sub email_exists_by_rid {
    my ($self, $email, $rid) = @_;

    my ($count) = $self->{'dbh'}->selectrow_array(
        "SELECT COUNT(*) FROM maillist WHERE ml_resp_id=? AND ml_email=?",
        { 'Slice' => {} },
        $rid,
        $email,
    );
    return $count;
}


sub get_patients_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_search_by_name(
    	'PId, FName, LName, BDate, Phone, Status', 
    	'patients', 
    	$fname, 
    	$lname,
    );
}

sub get_patients_by_name_and_ids {
    my ($self, $fname, $lname, $ids) = @_;

    return $self->_search_by_name(
    	'PId, FName, LName, BDate, Phone, Status', 
    	'patients', 
    	$fname, 
    	$lname, 
    	"PId IN (".join(', ', map {$self->{'dbh'}->quote($_)} @$ids).")",
    );
}

sub get_patients_by_name_and_phone_and_ids {
    my ($self, $fname, $lname, $phone, $ids) = @_;

    return $self->_search_by_name(
    	'PId, FName, LName, BDate, Phone, Status', 
    	'patients', 
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
		"SELECT PId, FName, LName, BDate, Phone, Status FROM patients WHERE PId=?",
		undef,
		$pid,
	);
}

sub get_patient_ids_by_responsible {
    my ($self, $rid) = @_;

    return $self->{'dbh'}->selectcol_arrayref(
        "SELECT PId FROM prlinks WHERE RId=?",
        undef,
        $rid,
    );
}

sub get_responsible_ids_by_patient {
    my ($self, $pid) = @_;

    return $self->{'dbh'}->selectcol_arrayref(
        "SELECT RId FROM prlinks WHERE PId=?",
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
	my $sql = sprintf(<<'SQL', @params);
INSERT INTO maillist 
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



1;