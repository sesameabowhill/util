## $Id$

use strict;
use warnings;

use lib qw(../lib);

use CandidateManager;
use DataSource::DB;
use Repair::RepairClincheck;

{
	my (@clients) = @ARGV;
	if (@clients) {
	    my $start_time = time();
		my $data_source = DataSource::DB->new();
		$data_source->set_read_only(1);
		@clients = @{ $data_source->expand_client_group( \@clients ) };
	    for my $client_identity (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_identity);
			printf "database source: client [%s]\n", $client_identity;
	    	match_invisalign_patients($client_data);
	    }
		my $fn = "_match_invisalign_patients.sql";
		printf "write match commands to [$fn]\n";
		$data_source->save_sql_commands_to_file($fn);
		$data_source->print_category_stat();
	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
	    print "Usage: $0 <database1> [database2...]\n";
	    exit(1);
	}
}

sub match_invisalign_patients {
	my ($start_client_data) = @_;

	my $repair_module = Repair::RepairClincheck->new();

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
					$client_data->register_category("matched invisalign patient");

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
					$client_data->register_category("invisalign patient is matched to orphan patient");
				}
			}
			else {
				for my $current_client_data (@all_affected_clients) {
					my $sesame_patient_id = $repair_module->match_to_sesame_patient(
						$current_client_data,
						$inv_patient,
					);
					if (defined $sesame_patient_id) {
						$current_client_data->set_sesame_patient_for_invisalign_patient(
							$inv_patient->{'case_number'},
							$sesame_patient_id,
						);
						printf(
							"MATCH [%s]: matched patient [%s %s] to [%s] at [%s]\n",
							$inv_patient->{'case_number'},
							$inv_patient->{'fname'},
							$inv_patient->{'lname'},
							$sesame_patient_id,
							$current_client_data->get_username(),
						);
						if ($current_client_data->get_username() eq $client_data->get_username()) {
							$current_client_data->register_category("found sesame patient for invisalign patient");
						}
						else {
							my $new_invisaling_client_id = $current_client_data->get_invisalign_client_by_shared_invisalign_client(
								$inv_patient->{'invisalign_client_id'},
							);
							if (defined $new_invisaling_client_id) {
								$current_client_data->register_category("found sesame patient for invisalign patient (with different client)");
								$current_client_data->set_invisalign_client_id_for_invisalign_patient(
									$inv_patient->{'case_number'},
									$new_invisaling_client_id,
								);
							}
							else {
								$current_client_data->register_category("found sesame patient for invisalign patient (with different client) (no new inv id found)");
							}
						}
						next PATIENT;
					}
				}
				$client_data->register_category("can't match invisalign patient");
			}
		}
	}
}