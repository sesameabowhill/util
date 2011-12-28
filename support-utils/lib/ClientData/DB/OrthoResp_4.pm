## $Id$
package ClientData::DB::OrthoResp_4;

use strict;
use warnings;

use base qw( ClientData::DB::Ortho_4 );

sub get_full_type {
	my ($class) = @_;

	return 'ortho_resp';
}

sub count_emails_by_pid {
	my ($self, $pid) = @_;

	my %emails;
	for my $rid (@{ $self->get_responsible_ids_by_patient($pid) }) {
		for my $email (@{ $self->get_emails_by_responsible($rid) }) {
			$emails{ lc($email->{'Email'}) } = 1;
		}
	}
	return scalar keys %emails;
}

sub get_all_sesame_accounts {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT SAId as RId, PSWD as Password, PrivacyPolicy, blocked as Blocked FROM ".$self->{'db_name'}.".sesame_accounts",
		{ 'Slice' => {} },
	);
}

sub get_sent_mail_log_by_rid {
	my ($self, $rid) = @_;

    return $self->{'dbh'}->selectall_arrayref(
        "SELECT ".$self->_get_sent_mail_log_fields()." FROM ".$self->{'db_name'}.".sent_mail_log WHERE sml_resp_id=? ORDER BY sml_date",
		{ 'Slice' => {} },
        $rid,
    );
}

1;