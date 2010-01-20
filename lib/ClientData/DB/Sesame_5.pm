## $Id$
package ClientData::DB::Sesame_5;

use strict;
use warnings;

use base qw( ClientData::DB );

use Sesame::Unified::Client;

sub new {
	my ($class, $data_source, $db_name, $dbh, $unified_client_ref) = @_;

	unless (defined $unified_client_ref) {
		$unified_client_ref = Sesame::Unified::Client->new('db_name', $db_name);
	}
	my $self = $class->SUPER::new($data_source, $db_name, $unified_client_ref);
	$self->{'client_id'} = $self->{'client_ref'}->get_id();
	$self->{'dbh'} = $dbh;
	return $self;
}

sub get_db_name {
	my ($self) = @_;

	return $self->get_username();
}

sub get_username {
	my ($self) = @_;

	return $self->{'client_ref'}->get_username();
}

sub is_active {
	my ($self) = @_;

	return $self->{'client_ref'}->is_active();
}

sub get_id {
	my ($self) = @_;

	return $self->{'client_ref'}->get_id();
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

sub get_patients_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_get_visitors_by_name(
    	'id AS PId',
    	$fname,
    	$lname,
    	'type="patient"',
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

    return 'id, address_id, type, first_name AS FName, last_name AS LName, birthday AS BDate, blocked, blocked_source, privacy, password, no_email, active, active_in_pms';
}

sub get_all_patients {
    my ($self) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT id AS PId, ".$self->_get_visitor_columns()." FROM visitor WHERE type='patient' AND client_id=?",
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

	my $inv_client_ids = $self->_get_invisalign_client_ids();

	if (@$inv_client_ids) {
		return $self->_search_with_fields_by_name(
	    	$self->_get_invisalign_patient_columns(),
	    	'fname',
	    	'lname',
	    	'invisalign_patient',
	    	$fname,
	    	$lname,
	    	"invisalign_client_id IN (".join(
	        	", ",
	        	map { $self->{'dbh'}->quote($_) } @$inv_client_ids
	        ).")",
	    );
	}
	else {
		return [];
	}
}

sub get_all_invisalign_patients {
	my ($self) = @_;

	my $inv_client_ids = $self->_get_invisalign_client_ids();

	if (@$inv_client_ids) {
		return $self->{'dbh'}->selectall_arrayref(
	        "SELECT ".$self->_get_invisalign_patient_columns()." FROM invisalign_patient
	        WHERE invisalign_client_id IN (".join(
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

sub set_sesame_patient_for_invisalign_patient {
	my ($self, $case_number, $sesame_patient_id) = @_;

	$self->{'dbh'}->do(
		"UPDATE invisalign_patient SET patient_id=? WHERE case_num=?",
		undef,
		$sesame_patient_id,
		$case_number,
	);
}

sub _get_invisalign_patient_columns {
	my ($self) = @_;

	return 'case_num AS case_number, invisalign_client_id, fname, lname, post_date, start_date, transfer_date, retire_date, stages, img_available, patient_id, refine, deleted';
}

sub add_email {
    my ($self, $visitor_id, $email, $belongs_to, $name, $status, $source) = @_;

	my @params = map {$self->{'dbh'}->quote($_)} (
		$visitor_id, $email, $belongs_to, $name,
		$status, $source,
		$self->{'client_id'},
    );
	my $sql = sprintf(<<'SQL', @params);
INSERT INTO email
	(visitor_id, email, date, responsible_type, relative_name,
	welcome_sent, source, deleted, deleted_datetime, deleted_source,
	client_id)
VALUES
	(%s, %s, NOW(), %s, %s,
	%s, %s, 'false', NULL, NULL,
	%s)
SQL
	$sql =~ s/\r?\n/ /g;
	$sql =~ s/\s+/ /g;
	$self->{'dbh'}->do($sql);
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

sub get_si_patient_by_id {
	my ($self, $pat_id) = @_;

	return $self->{'dbh'}->selectall_arrayref(
        "SELECT FName, LName, BDate FROM si_patient WHERE PatId=? AND client_id=?",
		{ 'Slice' => {} },
		$pat_id,
		$self->{'client_id'},
    )->[0];
}

sub get_hhf_id {
	my ($self) = @_;

	return scalar $self->{'dbh'}->selectrow_array(
		"SELECT guid FROM hhf_client_settings WHERE client_id=?",
		undef,
		$self->{'client_id'},
	);
}

sub get_profile_value {
	my ($self, $key) = @_;

	return $self->_get_profile_value(
		$key,
		'client_setting',
		'client_id=' . $self->{'dbh'}->quote( $self->{'client_id'} ),
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

sub add_hhf_form {
	my ($self, $filldate, $fname, $lname, $birthdate, $note, $signature, $body) = @_;

	$self->{'dbh'}->do(<<'SQL',
INSERT INTO hhf_applications (client_id, filldate, fname, lname, birthdate, note, signature, body)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
SQL
		undef,
		$self->{'client_id'},
		$filldate,
		$fname,
		$lname,
		$birthdate,
		$note,
		$signature,
		$body,
	);
}


1;