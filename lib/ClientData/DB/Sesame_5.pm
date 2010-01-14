## $Id$
package ClientData::DB::Sesame_5;

use strict;
use warnings;

use base qw( ClientData::DB );


sub new {
	my ($class, $data_source, $db_name, $dbh, $unified_client_ref) = @_;

	my $self = $class->SUPER::new($data_source, $db_name, $unified_client_ref);
	$self->{'client_id'} = $self->{'client_ref'}->get_id();
	$self->{'dbh'} = $dbh;
	return $self;
}

sub get_db_name {
	my ($self) = @_;

	return $self->{'client_ref'}->get_db_name();
}

sub is_active {
	my ($self) = @_;

	return $self->{'client_ref'}->is_active();
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
    	$fname,
    	$lname,
    	'type="patient"',
    );
}

sub get_responsibles_by_name {
    my ($self, $fname, $lname) = @_;

    return $self->_get_visitors_by_name(
    	$fname,
    	$lname,
    	'type="responsible"',
    );
}

sub _get_visitors_by_name {
    my ($self, $fname, $lname, $where) = @_;

    return $self->_search_with_fields_by_name(
    	'id, address_id, type, first_name AS FName, last_name AS LName, birthday AS BDate, blocked, blocked_source, privacy, password, no_email, active, active_in_pms',
    	'first_name',
    	'last_name',
    	'visitor',
    	$fname,
    	$lname,
    	'client_id='.$self->{'dbh'}->quote($self->{'client_id'}).' AND '.$where,
    );
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


1;