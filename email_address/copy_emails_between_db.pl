#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw( ../lib );

use CandidateManager;
use DataSource::DB;

my ($db_from, $db_to, $db_from_connection, $db_to_connection) = @ARGV;

if (defined $db_to) {
	printf("copying emails from [%s] to [%s]\n", $db_from, $db_to);
	my $data_source_from = (
		$db_from =~ s/^4:// ?
			DataSource::DB->new_4($db_from_connection) :
			DataSource::DB->new(undef, $db_from_connection)
	);
	my $data_source_to   = DataSource::DB->new(undef, $db_to_connection);
	$data_source_from->set_read_only(1);
	$data_source_to->set_read_only(1);
	printf(
		"copy emails from [%s] (%s) -> [%s] (%s)\n",
		$db_from,
		$data_source_from->get_connection_info(),
		$db_to,
		$data_source_to->get_connection_info(),
	);
	my $client_data_from = $data_source_from->get_client_data_by_db($db_from);
	my $client_data_to   = $data_source_to->get_client_data_by_db($db_to);

	my %candidate_selectors = (
		'ortho_resp' => {
			'ortho_resp' => \&select_candidate_resp_resp,
			'sesame' => \&select_candidate_resp_sesame,
		},
		'ortho_pat' => {
			'ortho_resp' => \&select_candidate_pat_resp,
		},
		'sesame' => {
			'sesame' => \&select_candidate_sesame_sesame,
		},
	);
	my %add_email = (
		'ortho_resp' => \&add_email_with_responsible_party,
		'sesame' => \&add_email_to_visitor,
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

	my $start_time = time();
	my $from_emails = $client_data_from->get_all_emails();
	my $added_count = 0;
	for my $from_email (@$from_emails) {
		if ($client_data_to->email_is_used( $from_email->{'Email'} )) {
			printf(
				"SKIP: email [%s] is already used\n",
				$from_email->{'Email'},
			);
		}
		else {
			my $candidate_manager = CandidateManager->new(
				{
					'by_pat_resp_with_phone' => 1,
					'by_pat_resp' => 2,
					'by_resp' => 3,
					'by_pat' => 4,
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
				printf(
					"ADD: %s\n",
					$from_email->{'Email'},
				);
				$add_email{ $client_data_to->get_full_type() }->(
					$client_data_to,
					$from_email,
					$candidate,
				);
#				$client_data_to->add_email(
#					(defined $candidate->{'patient'} ? $candidate->{'patient'}{'PId'} : 0 ),
#					$candidate->{'responsible'}{'RId'},
#					$from_email->{'Email'},
#					$from_email->{'BelongsTo'},
#					$from_email->{'Name'},
#					$from_email->{'Status'},
#					$from_email->{'Source'},
#				);
				$added_count++;
			}
			else {
				printf(
					"SKIP: %s - %s\n",
					$from_email->{'Email'},
					$candidate_manager->candidates_count_str(),
				);
			}
		}
	}
#    for my $sql (@{ $data_source->get_statements() }) {
#        print "$sql;\n";
#    }
	my $result_sql_fn = '_new_email.'.$db_to.'.sql';
	printf("write sql commands to [$result_sql_fn]\n");
	$data_source_to->save_sql_commands_to_file($result_sql_fn);
	printf("[%d] of [%d] emails added\n", $added_count, scalar @$from_emails);
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print("Usage: $0 <db_from> <db_to> [db_from_connection] [db_to_connection]\n");
	exit(1);
}

sub select_candidate_resp_sesame {
	my ($from_email, $client_data_from, $client_data_to, $candidate_manager) = @_;

	if ($from_email->{'RId'}) {
		my $from_responsible = $client_data_from->get_responsible_by_id(
			$from_email->{'RId'},
		);
		my $to_visitors = $client_data_to->get_responsibles_by_name(
			$from_responsible->{'FName'},
			$from_responsible->{'LName'},
		);
		for my $visitor (@$to_visitors) {
			$candidate_manager->add_candidate(
				'by_resp',
				$visitor,
			);
		}
		if ($from_email->{'PId'}) {
			my $from_patient = $client_data_from->get_patient_by_id(
				$from_email->{'PId'},
			);
			my $to_pat_visitors = $client_data_to->get_patients_by_name(
				$from_patient->{'FName'},
				$from_patient->{'LName'},
			);
			for my $visitor (@$to_pat_visitors) {
				$candidate_manager->add_candidate(
					'by_pat',
					$visitor,
				);
			}
		}
	}
}

sub select_candidate_sesame_sesame {
	my ($from_email, $client_data_from, $client_data_to, $candidate_manager) = @_;

	my $visitor = $client_data_from->get_visitor_by_id( $from_email->{'VisitorId'} );
	if ($visitor->{'type'} eq 'patient') {
		my $patients = $client_data_to->get_patients_by_name($visitor->{'FName'}, $visitor->{'LName'});
		for my $patient (@$patients) {
			$candidate_manager->add_candidate(
				'by_pat',
				$patient,
			);
		}
	}
	else {
		my $responsibles = $client_data_to->get_responsibles_by_name($visitor->{'FName'}, $visitor->{'LName'});
		for my $responsible (@$responsibles) {
			$candidate_manager->add_candidate(
				'by_resp',
				$responsible,
			);
		}
	}
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

sub add_email_with_responsible_party {
	my ($client_data, $email, $candidate) = @_;

	$client_data->add_email(
		(defined $candidate->{'patient'} ? $candidate->{'patient'}{'PId'} : 0 ),
		$candidate->{'responsible'}{'RId'},
		$email->{'Email'},
		$email->{'BelongsTo'},
		$email->{'Name'},
		$email->{'Status'},
		$email->{'Source'},
	);

}

sub add_email_to_visitor {
	my ($client_data, $email, $candidate) = @_;

	my %source_map = (
		'sesame'     => 'sesame',
		'staff'      => 'staff',
		'cp'         => 'cp',
		'web_emc'    => 'online_collector',
		'office_emc' => 'office_collector',
		'doctor_db'  => 'pms_old',
		'other'      => 'other',
		'online_collector' => 'online_collector',
		'office_collector' => 'office_collector',
		'pms_old'    => 'pms_old',
		'pms_new'    => 'pms_new',
	);
	my %resp_type = (
		'0' => '',
		'1' => 'family',
		'2' => 'mother',
		'3' => 'father',
		'4' => 'other',
		''       => '',
		'family' => 'family',
		'mother' => 'mother',
		'father' => 'father',
		'other'  => 'other',
	);

	my $visitor = $candidate;
	$client_data->add_email(
		$visitor->{'id'},
		$email->{'Email'},
		( exists $resp_type{ $email->{'BelongsTo'} } ? $resp_type{ $email->{'BelongsTo'} } : 'other' ),
		$email->{'Name'},
		( exists $source_map{ $email->{'Source'} } ? $source_map{ $email->{'Source'} } : 'other' ),
		$email->{'Deleted'},
	);
}

