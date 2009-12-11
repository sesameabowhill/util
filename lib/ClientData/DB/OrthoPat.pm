## $Id$
package ClientData::DB::OrthoPat;

use base qw( ClientData::DB::Ortho );

sub get_full_type {
	my ($class) = @_;

	return 'ortho_pat';
}

sub count_emails_by_pid {
	my ($self, $pid) = @_;

	my %emails = map {lc($_->{'Email'}) => 1} @{ $self->get_emails_by_pid($pid) };
	return scalar keys %emails;
}



1;