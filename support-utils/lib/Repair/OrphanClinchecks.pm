## $Id$
package Repair::OrphanClinchecks;

use strict;
use warnings;

use base 'Repair::Base';

## Repair::OrphanClinchecks::repair
sub repair {
	my ($self, $client_data) = @_;

	my $patients = $client_data->get_all_patients();
	my %invisalign_client_ids = map { $_ => 1 } @{ $client_data->get_invisalign_client_ids() };
	for my $patient (@$patients) {
		my $invisaling_patients = $client_data->get_invisalign_patients_by_patient_id($patient->{'PId'});
		if (@$invisaling_patients) {
			for my $invisaling_patient (@$invisaling_patients) {
				my $invisalign_client_id = $invisaling_patient->{'invisalign_client_id'};
				if (exists $invisalign_client_ids{$invisalign_client_id})  {
					$self->{'logger'}->register_category('invisaling patient with good client link');
				} else {
					$self->{'logger'}->register_category('invisaling patient with broken client link');
					$client_data->delete_invisalign_patient_by_id($invisaling_patient->{'id'}, $client_data->get_username().": invisalign_client_id ".$invisalign_client_id);
				}
			}
		} else {
			$self->{'logger'}->register_category('patient without invisaling');
		}
	}

}

1;

