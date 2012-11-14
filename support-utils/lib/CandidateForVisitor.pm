package CandidateForVisitor;

use strict;
use warnings;

sub match_visitor {
	my ($class, $candidate_manager, $visitor, $client_data) = @_;

	if ($visitor->{'type'} eq 'patient') {
		if ($candidate_manager->can_use_priority('by_pms_id')) {
			my $patients = $client_data->get_patients_by_pms_id( $visitor->{'pms_id'} );
			for my $patient (@$patients) {
				$candidate_manager->add_candidate(
					'by_pms_id',
					$patient,
				);
			}
		}
		{
			my $patients = $client_data->get_patients_by_name($visitor->{'FName'}, $visitor->{'LName'});
			for my $patient (@$patients) {
				$candidate_manager->add_candidate(
					'by_pat',
					$patient,
				);
			}
		}
		{
			my $patients = $client_data->get_patients_by_name_and_pms_id(
				$visitor->{'FName'},
				$visitor->{'LName'},
				$visitor->{'pms_id'},
			);
			for my $patient (@$patients) {
				$candidate_manager->add_candidate(
					'by_pms_pat',
					$patient,
				);
			}
		}
	}
	else {
		if ($candidate_manager->can_use_priority('by_pms_id')) {
			my $responsibles = $client_data->get_responsibles_by_pms_id( $visitor->{'pms_id'} );
			for my $responsible (@$responsibles) {
				$candidate_manager->add_candidate(
					'by_pms_id',
					$responsible,
				);
			}
		}
		{
			my $responsibles = $client_data->get_responsibles_by_name($visitor->{'FName'}, $visitor->{'LName'});
			for my $responsible (@$responsibles) {
				$candidate_manager->add_candidate(
					'by_resp',
					$responsible,
				);
			}
		}
		{
			my $responsibles = $client_data->get_responsibles_by_name_and_pms_id(
				$visitor->{'FName'},
				$visitor->{'LName'},
				$visitor->{'pms_id'},
			);
			for my $responsible (@$responsibles) {
				$candidate_manager->add_candidate(
					'by_pms_resp',
					$responsible,
				);
			}
		}
	}
}


1;