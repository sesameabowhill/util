## $Id$
package ClientData::DB::Sesame_6;

use strict;
use warnings;

use File::Spec;

use base qw( ClientData::DB::Sesame_5 );

sub _get_email_sent_mail_log_select {
	my ($self) = @_;

	return "SELECT l.id, l.visitor_id, sml_email AS Email, sml_name AS Name, sml_mail_type, sml_date AS DateTime, sml_mail_id, sml_body as Body, sml_body_hash, contact_log_id FROM email_sent_mail_log l";
}

sub get_all_sent_emails_with_body {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		$self->_get_email_sent_mail_log_select()." WHERE l.client_id=? AND NOT sml_body LIKE 'file://%'",
		{ 'Slice' => {} },
		$self->{'client_id'},
	);
}


1;