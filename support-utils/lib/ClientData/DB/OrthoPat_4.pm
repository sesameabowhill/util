## $Id$
package ClientData::DB::OrthoPat_4;

use strict;
use warnings;

use base qw( ClientData::DB::Ortho_4 );

sub get_full_type {
	my ($class) = @_;

	return 'ortho_pat';
}

sub count_emails_by_pid {
	my ($self, $pid) = @_;

	my %emails = map {lc($_->{'Email'}) => 1} @{ $self->get_emails_by_pid($pid) };
	return scalar keys %emails;
}

sub get_all_sesame_accounts {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT SAId as PId, PSWD as Password, PrivacyPolicy, blocked as Blocked FROM ".$self->{'db_name'}.".sesame_accounts",
		{ 'Slice' => {} },
	);
}

sub get_sent_mail_log_by_pid {
	my ($self, $pid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT ".$self->_get_sent_mail_log_fields()." FROM ".$self->{'db_name'}.".sent_mail_log WHERE sml_pat_id=? ORDER BY sml_date",
		{ 'Slice' => {} },
        $pid,
    );
}


1;