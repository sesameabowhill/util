## $Id$
use strict;
use warnings;

use lib qw( ../lib );

use DataSource::DB;

my @clients = @ARGV;
if (@clients) {
	my $start_time = time();
	my $add_email_count = 0;

	my $data_source = DataSource::DB->new();
	my $last_client_db = undef;
	for my $client_identity (@clients) {
		my $client_data = $data_source->get_client_data_by_db($client_identity);
		$add_email_count += copy_emails_from_resp_to_pat($client_data);
	}

	print "[$add_email_count] emails added\n";
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 <client_db1> ...\n";
	exit(1);
}


sub copy_emails_from_resp_to_pat {
	my ($client_data) = @_;

	my $add_email_count = 0;
	my $responsibles = $client_data->get_all_responsibles();
	for my $responsible (@$responsibles) {
		my $responsible_emails = $client_data->get_emails_by_responsible($responsible->{'RId'});
		if (@$responsible_emails) {
			my $patients_ids = $client_data->get_patient_ids_by_responsible($responsible->{'RId'});
			if (@$patients_ids) {
				my $self_patients = $client_data->get_patients_by_name_and_ids(
					$responsible->{'FName'},
					$responsible->{'LName'},
					$patients_ids,
				);
				if (@$self_patients == 1) {
					my $self_patient = $self_patients->[0];
					my $self_patient_emails = $client_data->get_emails_by_pid($self_patient->{'PId'});
					if (@$self_patient_emails) {
						printf(
							"SKIP [%s]: responsible [%s]: self patient [%s] has email\n",
							$client_data->get_username(),
							$responsible->{'RId'},
							$self_patient->{'PId'},
						);
					}
					else {
						$add_email_count++;
						## get first random email
						my $email = $responsible_emails->[0];
						printf(
							"ADD [%s]: responsible [%s]: add email to patient [%s]\n",
							$client_data->get_username(),
							$responsible->{'RId'},
							$self_patient->{'PId'},
						);
						$client_data->add_email(
    						$self_patient->{'PId'},
    						$email->{'Email'},
    						$email->{'BelongsTo'},
    						$email->{'Name'},
    						($email->{'Status'} ? 'true' : 'false'),
    						'other',
    					);
					}
				}
				else {
					printf(
						"SKIP [%s]: responsible [%s]: no \"self\" patient\n",
						$client_data->get_username(),
						$responsible->{'RId'},
					);
				}
			}
			else {
				printf(
					"SKIP [%s]: responsible [%s]: no patients\n",
					$client_data->get_username(),
					$responsible->{'RId'},
				);
			}
		}
		else {
			printf(
				"SKIP [%s]: responsible [%s]: no email\n",
				$client_data->get_username(),
				$responsible->{'RId'},
			);
		}
	}
	return $add_email_count;
}