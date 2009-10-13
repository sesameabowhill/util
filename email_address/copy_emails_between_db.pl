#!/usr/bin/perl
## $Id$

use strict;

use lib qw( ../lib );

use CandidateManager;
use DataSource::DB;

my ($db_from, $db_to) = @ARGV;

if (defined $db_to) {
	printf("coping emails from [%s] to [%s]\n", $db_from, $db_to);
	my $data_source = DataSource::DB->new();
	my $client_data_from = $data_source->get_client_data_by_db($db_from);
	my $client_data_to   = $data_source->get_client_data_by_db($db_to);
	
	my %candidate_selectors = (
		'ortho_resp' => {
			'ortho_resp' => \&select_candidate_resp_resp,
		},
		'ortho_pat' => {
			'ortho_resp' => \&select_candidate_pat_resp,
		},
	);
	my $candidate_selector = 
		$candidate_selectors{
			$client_data_from->get_full_type() 
		}{
			$client_data_to->get_full_type() 
		};
	unless (defined $candidate_selector) {
		die "can't convert data from [".$client_data_from->get_full_type()."] to [".$client_data_to->get_full_type()."]";
	}
	
	my $from_emails = $client_data_from->get_all_emails();
	my $added_count = 0;
	for my $from_email (@$from_emails) {
		my $candidate_manager = CandidateManager->new(
			{
				'by_pat_resp_with_phone' => 1,
				'by_pat_resp' => 2,
				'by_resp' => 3,
			}
		);
		
		$candidate_selector->(
			$from_email, 
			$client_data_from, 
			$client_data_to, 
			$candidate_manager,
		);

		my $candidate = $candidate_manager->get_single_candidate();
		if (defined $candidate) {
			my $email_exists;
			if ($client_data_to->get_full_type() eq 'ortho_resp') {
				$email_exists = $client_data_to->email_exists_by_rid(
					$from_email->{'Email'},
					$candidate->{'responsible'}{'RId'},
				);
			}
			else {
				die "email exists not implemented for [".$client_data_to->get_full_type()."] type";
			}
			if ($email_exists) {
				printf(
					"SKIP: email [%s] is already added\n", 
					$from_email->{'Email'}, 
				);
			}
			else {
				printf(
					"ADD: %s\n", 
					$from_email->{'Email'}, 
				);
				$client_data_to->add_email(
					(defined $candidate->{'patient'} ? $candidate->{'patient'}{'PId'} : 0 ),
					$candidate->{'responsible'}{'RId'},
					$from_email->{'Email'},
					$from_email->{'BelongsTo'},
					$from_email->{'Name'},
					$from_email->{'Status'},
					$from_email->{'Source'},
				);
				$added_count++;
			}
		}
		else {
			printf(
				"SKIP: %s - %s\n", 
				$from_email->{'Email'}, 
				$candidate_manager->candidates_count_str(),
			);
		}
	}
#    for my $sql (@{ $data_source->get_statements() }) {
#        print "$sql;\n";
#    }
	my $result_sql_fn = '_new_email.'.$db_to.'.sql';
	printf("write sql commands to [$result_sql_fn]\n");
	$data_source->save_sql_commands_to_file($result_sql_fn);
	printf("[%d] emails added\n", $added_count);
}
else {
	print("Usage: $0 <db_from> <db_to>\n");
	exit(1);
}


sub select_candidate_resp_resp {
	my ($from_email, $client_data_from, $client_data_to, $candidate_manager) = @_;
	
	if ($from_email->{'RId'}) {
		my $from_responsible = $client_data_from->get_responsible_by_id(
			$from_email->{'RId'},
		);
		my $to_responsibles = $client_data_to->get_responsible_ids_by_name( 
			$from_responsible->{'FName'}, 
			$from_responsible->{'LName'}, 
		);
		for my $to_responsible (@$to_responsibles) {
			if ($from_email->{'PId'}) {
				select_candidate_for_patient(
					$client_data_from, 
					$client_data_to, 
					$to_responsible, 
					$from_email->{'PId'}, 
					$candidate_manager,
				);
			}
			else {
				$candidate_manager->add_candidate(
					'by_resp',
					{
						'patient' => undef,
						'responsible' => $to_responsible,
					},
				);
			}
		}
	}
}

sub select_candidate_for_patient {
	my ($client_data_from, $client_data_to, $to_responsible, $from_pid, $candidate_manager) = @_;
	
	my $from_patient = $client_data_from->get_patient_by_id(
		$from_pid,
	);
	my $to_patients_ids = $client_data_to->get_patient_ids_by_responsible(
		$to_responsible->{'RId'},
	);
	my $to_patients = $client_data_to->get_patients_by_name_and_ids( 
		$from_patient->{'FName'}, 
		$from_patient->{'LName'},
		$to_patients_ids,
	);
	for my $to_patient (@$to_patients) {
		$candidate_manager->add_candidate(
			'by_pat_resp',
			{
				'patient' => $to_patient,
				'responsible' => $to_responsible,
			},
		);
	}
	if ($from_patient->{'Phone'}) {
		my $to_patients_with_phone = $client_data_to->get_patients_by_name_and_phone_and_ids( 
			$from_patient->{'FName'}, 
			$from_patient->{'LName'},
			$from_patient->{'Phone'},
			$to_patients_ids,
		);
		for my $to_patient (@$to_patients_with_phone) {
			$candidate_manager->add_candidate(
				'by_pat_resp_with_phone',
				{
					'patient' => $to_patient,
					'responsible' => $to_responsible,
				},
			);
		}
	}
}

sub select_candidate_pat_resp {
	my ($from_email, $client_data_from, $client_data_to, $candidate_manager) = @_;
	
	if ($from_email->{'PId'}) {
		my $from_patient = $client_data_from->get_patient_by_id($from_email->{'PId'});
		my $from_responsibles;
		if ($from_email->{'RId'}) {
			$from_responsibles = [ $from_email->{'RId'} ];
		}
		else {
			$from_responsibles = $client_data_from->get_responsible_ids_by_patient($from_email->{'PId'});
		}
		
		for my $from_responsible_id (@$from_responsibles) {
			my $from_responsible = $client_data_from->get_responsible_by_id($from_responsible_id);

			my $to_responsibles = $client_data_to->get_responsible_ids_by_name( 
				$from_responsible->{'FName'}, 
				$from_responsible->{'LName'}, 
			);
			for my $to_responsible (@$to_responsibles) {
				select_candidate_for_patient(
					$client_data_from, 
					$client_data_to, 
					$to_responsible, 
					$from_email->{'PId'}, 
					$candidate_manager,
				);
			}
		}
	}
}


