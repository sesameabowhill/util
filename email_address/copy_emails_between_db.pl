#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use Email::Valid;
use Getopt::Long;
use Hash::Util qw( lock_keys );

use lib qw( ../lib );

use CandidateManager;
use DataSource::DB;
use DataSource::PMSMigrationBackup;
use Logger;
use Script;

my $match_by_pms_id = 0;
my $add_duplicated_emails = 0;
my $load_emails_from_archive = undef;
GetOptions(
	'match-by-pms-id!' => \$match_by_pms_id,
	'add-duplicated-emails!' => \$add_duplicated_emails,
	'load-emails-from-archive=s' => \$load_emails_from_archive,
);
if (defined $load_emails_from_archive && $load_emails_from_archive !~ m{^\d{4}-\d{2}-\d{2}$}) {
	die "invalid options value --load-emails-from-archive=$load_emails_from_archive";
}

my ($db_from_param, $db_to, $db_from_connection, $db_to_connection) = @ARGV;

if (defined $db_to) {
	my $logger = Logger->new();

	my ($db_from, $data_source_from) = Script->choose_data_source_by_username($db_from_param, $db_from_connection);
	my $data_source_to = DataSource::DB->new(undef, $db_to_connection);
	$data_source_from->set_read_only(1);
	$data_source_to->set_read_only(1);
	$logger->printf(
		"copy emails from [%s] (%s) -> [%s] (%s)",
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
	my $from_emails = (
		defined $load_emails_from_archive ?
			load_emails_from_archive($logger, $client_data_from, $load_emails_from_archive) :
			$client_data_from->get_all_emails()
	);
	my $added_count = 0;
	my %just_added_email;
	for my $from_email (@$from_emails) {
		if (Email::Valid->address($from_email->{'Email'})) {
			my $add_email;
			if ($add_duplicated_emails) {
				$add_email = 1;
			}
			else {
				if ($client_data_to->email_is_used( $from_email->{'Email'} )) {
					$logger->printf_slow(
						"SKIP: email [%s] is already used",
						$from_email->{'Email'},
					);
					$logger->register_category('email exists');
					$add_email = 0;
				}
#				elsif (exists $just_added_email{ trim_email( $from_email->{'Email'} ) }) {
#					$logger->printf_slow(
#						"SKIP: email [%s] is already added",
#						$from_email->{'Email'},
#					);
#					$logger->register_category('email is already added');
#					$add_email = 0;
#				}
				else {
					$add_email = 1;
				}
			}
			if ($add_email) {
				my $candidate_manager = CandidateManager->new(
					{
						($match_by_pms_id ? ( 'by_pms_id' => 1 ) : () ),
						'by_pat_resp_with_phone' => 2,
						'by_pat_resp' => 3,
						'by_pms_resp' => 4,
						'by_pms_pat' => 5,
						'by_resp' => 6,
						'by_pat' => 7,
					}
				);

				$candidate_selector->(
					$from_email,
					$client_data_from,
					$client_data_to,
					$candidate_manager,
				);

				my ($candidate, $found_by) = $candidate_manager->get_single_candidate_with_priority();
				if (defined $candidate) {
					$logger->printf_slow(
						"ADD: %s by %s",
						$from_email->{'Email'},
						$found_by,
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
					$just_added_email{ trim_email( $from_email->{'Email'} ) } = 1;
					$logger->register_category('email added (matched by '.$found_by.')');
				}
				else {
					$logger->printf_slow(
						"SKIP: %s - %s",
						$from_email->{'Email'},
						$candidate_manager->candidates_count_str(),
					);
					$logger->register_category('email not added (no candidate found)');
				}
			}
		}
		else {
			$logger->printf(
				"SKIP: email [%s] is invalid",
				$from_email->{'Email'},
			);
			$logger->register_category('email is invalid');
		}

	}
#    for my $sql (@{ $data_source->get_statements() }) {
#        print "$sql;\n";
#    }
	my $result_sql_fn = '_new_email.'.$db_to.'.sql';
	$logger->printf("write sql commands to [%s]", $result_sql_fn);
	$data_source_to->save_sql_commands_to_file($result_sql_fn);
	$logger->printf("[%d] of [%d] emails added", $added_count, scalar @$from_emails);
	$logger->print_category_stat();

	my $work_time = time() - $start_time;
	$logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
}
else {
	print <<USAGE;
Usage: $0 <username_from> <username_to> [db_from_connection] [db_to_connection] [...options]
Special username_from prefix:
    4: - data should be loaded from sesame 4 database
    pms_migration_backup: - data should be loaded from pms migration backup files
Options:
    --add-duplicated-emails - add duplicated emails
    --match-by-pms-id - allow to match using PMS id
    --load-emails-from-archive=YYYY-MM-DD - load emails based on email archive before date
USAGE
	exit(1);
}

sub load_emails_from_archive {
	my ($logger, $client_data, $max_date) = @_;

	if (length $max_date == 10) {
		$max_date .= ' 00:00:00';
	}
	$logger->printf("loading emails from email archive before [%s]", $max_date);
	my $all_visitors = $client_data->get_all_visitors();
	my @emails;
	for my $visitor (@$all_visitors) {
		my $sent_mail_log = $client_data->get_sent_mail_log_by_visitor_id( $visitor->{'id'} );
		my %emails;
		for my $sent_mail (@$sent_mail_log) {
			if ($sent_mail->{'Date'} lt $max_date) {
				$emails{ trim_email( $sent_mail->{'Email'} ) } = $sent_mail;
			}
		}
		$logger->printf_slow(
			"visitor #%d: [%d] email%s found",
			$visitor->{'id'},
			scalar keys %emails,
			(keys %emails == 1 ? '' : 's'),
		);
		for my $email (values %emails) {
			my %row = (
				'VisitorId' => $visitor->{'id'},
				'Email'     => $email->{'Email'},
				'BelongsTo' => $email->{'BelongsTo'},
				'Name'      => $email->{'Name'},
				'Source'    => 'other',
				'Deleted'   => 'false',
			);
			lock_keys(%row);
			push(@emails, \%row);
		}
	}
	return \@emails;
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
		if ($candidate_manager->can_use_priority('by_pms_id')) {
			my $patients = $client_data_to->get_patients_by_pms_id( $visitor->{'pms_id'} );
			for my $patient (@$patients) {
				$candidate_manager->add_candidate(
					'by_pms_id',
					$patient,
				);
			}
		}
		{
			my $patients = $client_data_to->get_patients_by_name($visitor->{'FName'}, $visitor->{'LName'});
			for my $patient (@$patients) {
				$candidate_manager->add_candidate(
					'by_pat',
					$patient,
				);
			}
		}
		{
			my $patients = $client_data_to->get_patients_by_name_and_pms_id(
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
			my $responsibles = $client_data_to->get_responsibles_by_pms_id( $visitor->{'pms_id'} );
			for my $responsible (@$responsibles) {
				$candidate_manager->add_candidate(
					'by_pms_id',
					$responsible,
				);
			}
		}
		{
			my $responsibles = $client_data_to->get_responsibles_by_name($visitor->{'FName'}, $visitor->{'LName'});
			for my $responsible (@$responsibles) {
				$candidate_manager->add_candidate(
					'by_resp',
					$responsible,
				);
			}
		}
		{
			my $responsibles = $client_data_to->get_responsibles_by_name_and_pms_id(
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

sub trim_email {
	my ($email) = @_;

	$email =~ s/^\s+|\s+$//g;
	return lc($email);
}
