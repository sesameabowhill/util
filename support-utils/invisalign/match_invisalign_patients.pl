#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw(../lib);

use CandidateManager;
use DataSource::DB;
use Repair::RepairClincheck;
use Script;

Script->simple_client_loop(
	\@ARGV,
	{
		'read_only' => 1,
		'client_data_handler' => \&match_invisalign_patients,
		'save_sql_to_file' => '_match_invisalign_patients.sql',
	}
);

sub match_invisalign_patients {
	my ($logger, $start_client_data) = @_;

	my $repair_module = Repair::RepairClincheck->new($logger);

	my $shared_client_data = $start_client_data->get_clients_who_share_invisalign_accounts();
	if (@$shared_client_data) {
		printf(
			"CLIENT [%s]: shares invisalign accounts with [%s]\n",
			$start_client_data->get_username(),
			join(', ', map { $_->get_username() } @$shared_client_data),
		);
	}
	my @all_affected_clients = ($start_client_data, @$shared_client_data);
	for my $client_data (@all_affected_clients) {
		my $all_invisalign_patients = $client_data->get_all_invisalign_patients();
		printf(
			"CLIENT [%s]: [%d] invisalign patient%s\n",
			$client_data->get_username(),
			scalar(@$all_invisalign_patients),
			(@$all_invisalign_patients == 1?'':'s'),
		);
		PATIENT:
		for my $inv_patient (@$all_invisalign_patients) {
			if ($inv_patient->{'patient_id'}) {
				my $sesame_patient = $client_data->get_patient_by_id( $inv_patient->{'patient_id'} );
				if (defined $sesame_patient) {
					$logger->register_category("matched invisalign patient");

				}
				else {
					$client_data->set_sesame_patient_for_invisalign_patient(
						$inv_patient->{'case_number'},
						undef,
					);
					printf(
						"UNMATCH [%s]: remove orphan patient link [%s %s] at [%s]\n",
						$inv_patient->{'case_number'},
						$inv_patient->{'fname'},
						$inv_patient->{'lname'},
						$client_data->get_username(),
					);
					$logger->register_category("invisalign patient is matched to orphan patient");
				}
			}
			else {
				for my $current_client_data (@all_affected_clients) {
					my $sesame_patient_id = $repair_module->match_to_sesame_patient(
						$current_client_data,
						$inv_patient,
					);
					if (defined $sesame_patient_id) {
						if ($current_client_data->get_username() eq $client_data->get_username()) {
							match_patient_to_sesame($current_client_data, $inv_patient, $sesame_patient_id);
							$logger->register_category("found sesame patient for invisalign patient");
						}
						else {
							my $new_invisaling_client_id = $current_client_data->get_invisalign_client_by_shared_invisalign_client(
								$inv_patient->{'invisalign_client_id'},
							);
							if (defined $new_invisaling_client_id) {
								match_patient_to_sesame($current_client_data, $inv_patient, $sesame_patient_id);
								$logger->register_category("found sesame patient for invisalign patient (with different client)");
								$current_client_data->set_invisalign_client_id_for_invisalign_patient(
									$inv_patient->{'case_number'},
									$new_invisaling_client_id,
								);
							}
							else {
								printf(
									"UNMOVABLE [%s]: from [%s] to [%s] patient [%s %s]\n",
									$inv_patient->{'case_number'},
									$client_data->get_username(),
									$current_client_data->get_username(),
									$inv_patient->{'fname'},
									$inv_patient->{'lname'},
								);
								$logger->register_category("found sesame patient with different client for invisalign patient, but no suitable invisalign account found");
							}
						}
						next PATIENT;
					}
				}
				$logger->register_category("can't match invisalign patient");
			}
		}
	}
}

sub match_patient_to_sesame {
	my ($client_data, $inv_patient, $sesame_patient_id) = @_;

	$client_data->set_sesame_patient_for_invisalign_patient(
		$inv_patient->{'case_number'},
		$sesame_patient_id,
	);
	printf(
		"MATCH [%s]: matched patient [%s %s] to [%s] at [%s]\n",
		$inv_patient->{'case_number'},
		$inv_patient->{'fname'},
		$inv_patient->{'lname'},
		$sesame_patient_id,
		$client_data->get_username(),
	);
}