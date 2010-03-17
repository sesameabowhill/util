#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use List::Util qw( first maxstr minstr );

use lib qw(../lib);

use CandidateManager;
use DataSource::DB;

{
	my (@clients) = @ARGV;
	if (@clients) {
		my $data_source = DataSource::DB->new();
		$data_source->set_read_only(1);
	    my $start_time = time();
	    for my $client_identity (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_identity);
			printf "database source: client [%s]\n", $client_identity;
	    	match_invisalign_patients($client_data);
	    }
		my $fn = "_match_invisalign_patients.sql";
		printf "write match commands to [$fn]\n";
		$data_source->save_sql_commands_to_file($fn);
	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
	    print "Usage: $0 <database1> [database2...]\n";
	    exit(1);
	}
}

sub match_invisalign_patients {
	my ($client_data) = @_;

	$client_data->set_approx_search(1);
	my $sesame_patients = $client_data->get_all_patients();
	my @unmatched_invisalign_patients = grep {!$_->{'patient_id'}} @{ $client_data->get_all_invisalign_patients() };
	my %matched_patients;
	for my $sesame_patient (@$sesame_patients) {
		my $candidate_manager = CandidateManager->new(
			{
				'by_name' => 1,
			}
		);
		my $inv_patients = $client_data->get_invisalign_patients_by_name(
			$sesame_patient->{'FName'},
			$sesame_patient->{'LName'},
		);
		for my $inv_patient (@$inv_patients) {
			$candidate_manager->add_candidate('by_name', $inv_patient);
		}
		my $candidate = $candidate_manager->get_single_candidate();
		if (defined $candidate) {
			if ($candidate->{'patient_id'}) {
				printf(
					"SKIP [%s %s]: already matched to [%s]\n",
					$candidate->{'fname'},
					$candidate->{'lname'},
					$candidate->{'patient_id'},
				);
			}
			else {
				$matched_patients{ $candidate->{'case_number'} }++;
				printf(
					"LINK [%s %s]: to sesame [%s %s]\n",
					$candidate->{'fname'},
					$candidate->{'lname'},
					$sesame_patient->{'FName'},
					$sesame_patient->{'LName'},
				);
				$client_data->set_sesame_patient_for_invisalign_patient(
					$candidate->{'case_number'},
					$sesame_patient->{'PId'},
				);
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
		scalar(keys %matched_patients),
		scalar(keys %matched_patients) + scalar(@unmatched_invisalign_patients),
	);
}