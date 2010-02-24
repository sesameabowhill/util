#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw(../lib);

use CandidateManager;
use DataSource::DB;

{
	my (@clients) = @ARGV;
	if (@clients) {
		my $data_source = DataSource::DB->new();
	    my $start_time = time();
	    for my $client_identity (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_identity);
			printf "database source: client [%s]\n", $client_identity;
	    	match_si_patients($client_data);
	    }
	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
	    print "Usage: $0 <database1> [database2...]\n";
	    exit(1);
	}
}

sub match_si_patients {
	my ($client_data) = @_;

	$client_data->set_approx_search(1);
	#my $sesame_patients = $client_data->get_all_patients();
	my $si_patients = $client_data->get_all_si_patients();
	my %matched_patients;
	my @unmatched_si_patients;
	for my $si_patient (@$si_patients) {
		my $linked_patients = $client_data->get_patients_linked_to_si_patient($si_patient->{'PatId'});
		if (@$linked_patients) {
			printf(
				"SKIP [%s %s]: already matched to [%s]\n",
				$si_patient->{'FName'},
				$si_patient->{'LName'},
				join(', ', @$linked_patients),
			);
		}
		else {
			my $candidate_manager = CandidateManager->new(
				{
					'by_birth' => 1,
					'by_name' => 2,
				}
			);
			{
				my $sesame_patients = $client_data->get_patients_by_name(
					$si_patient->{'FName'},
					$si_patient->{'LName'},
				);
				for my $sesame_patient (@$sesame_patients) {
					$candidate_manager->add_candidate('by_name', $sesame_patient);
				}
			}
			{
				my $sesame_patients = $client_data->get_patients_by_name_and_birth(
					$si_patient->{'FName'},
					$si_patient->{'LName'},
					$si_patient->{'BDate'},
				);
				for my $sesame_patient (@$sesame_patients) {
					$candidate_manager->add_candidate('by_birth', $sesame_patient);
				}
			}

			my $candidate = $candidate_manager->get_single_candidate();
			if (defined $candidate) {
				$matched_patients{ $si_patient->{'PatId'} }++;
				printf(
					"LINK [%s %s]: to sesame [%s %s] id [%s]\n",
					$si_patient->{'FName'},
					$si_patient->{'LName'},
					$candidate->{'FName'},
					$candidate->{'LName'},
					$candidate->{'PId'},
				);
				$client_data->link_si_patient(
					$candidate->{'PId'},
					$si_patient->{'PatId'},
				);
			}
			else {
				printf(
					"SKIP [%s %s]: can't match: %s\n",
					$si_patient->{'FName'},
					$si_patient->{'LName'},
					$candidate_manager->candidates_count_str(),
				);
				push(@unmatched_si_patients, $si_patient);
			}
		}
	}
#	print "-"x40,"\n";
#	for my $inv_pat (@unmatched_invisalign_patients) {
#		unless (exists $matched_patients{ $inv_pat->{'case_number'} }) {
#			printf("UNMATCHED [%s %s]\n", $inv_pat->{'fname'}, $inv_pat->{'lname'});
#		}
#	}
	printf(
		"[%d] of [%d] patients matched\n",
		scalar keys %matched_patients,
		scalar @unmatched_si_patients,
	);
}