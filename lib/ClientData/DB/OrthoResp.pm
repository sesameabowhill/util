## $Id$
package ClientData::DB::OrthoResp;

use base qw( ClientData::DB::Ortho );

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




1;