package Repair::InvisalignClientLinks;

use strict;
use warnings;

use base 'Repair::Base';

## Repair::InvisalignClientLinks::repair
sub repair {
	my ($self, $client_data) = @_;

	my $patients = $client_data->get_invisalign_processing_patients_by_client_id();
	if (defined $patients) {
		my %invisalign_client_ids = map { $_ => 1 } @{ $client_data->get_invisalign_client_ids() };
	
		for my $patient (@$patients) {
			if (exists $invisalign_client_ids{$patient->{'invisalign_client_id'}}) {
				$self->{'logger'}->register_category('invisalign client id is good');
			} else {
				$self->{'logger'}->register_category('invisalign client id is broken');
				$client_data->delete_invisalign_patient_by_invisalign_client($patient->{'case_number'}, $patient->{'invisalign_client_id'});
			}
		}
	} else {
		$self->{'logger'}->register_category('client does not have invisalign patients');
	}
}

1;