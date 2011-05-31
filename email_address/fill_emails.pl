## $Id$
use strict;
use warnings;

use Email::Valid;

use lib qw( ../lib );

use CandidateManager;
use CSVReader;
use DataSource::DB;
use Logger;


my @files = @ARGV;
if (@files) {
	my $start_time = time();
	my $add_email_count = 0;
	my $total_email_count = 0;
	my $logger = Logger->new();

	my %implemented = (
		'patient_emails' => {
			'ortho_resp' => {
				'candidate'   => \&find_patient_ortho_resp,
				'adder'       => \&add_email_with_responsible_patient,
				'file_format' => ['name', 'email'],
			},
			'sesame' => {
				'candidate'   => \&find_patient_by_name,
				'adder'       => \&add_email_to_visitor,
				'file_format' => ['name', 'email'],
			},
#			'dental' => \&add_email_to_patients_dental,
		},
		'responsible_emails' => {
			'ortho_resp' => {
				'candidate' => \&find_responsible_ortho_resp,
				'adder' => \&add_email_with_responsible_patient,
				'file_format' => ['name', 'email'],
			},
			'sesame' => {
				'candidate'   => \&find_responsible_by_name,
				'adder'       => \&add_email_to_visitor,
				'file_format' => ['name', 'email'],
			},
#			'dental' => \&add_email_to_responsibles_dental,
		},
		'pms_referrings' => {
			'ortho_resp' => {
				'function' => \&add_pms_referrings,
				'sep_char' => '|',
			},
			'ortho_pat' => {
				'function' => \&add_pms_referrings,
				'sep_char' => '|',
			},
			'dental' => {
				'function' => \&add_pms_referrings,
				'sep_char' => '|',
			},
		},
	);

	my $data_source = DataSource::DB->new();
	$data_source->set_read_only(1);
	my $last_client_db = undef;
	for my $file_name (@files) {
		if ($file_name =~ m/^_?(.*)\.(.*)\.(.*)$/) {
			my ($client_db, $type, $ext) = ($1, $2, $3);
			$client_db =~ s/^_//;
			$last_client_db = $client_db;

			my $client_data = $data_source->get_client_data_by_db($client_db);
			$client_data->set_approx_search(1);

			my $client_full_type = $client_data->get_full_type();
			$logger->printf("database source: client [%s] type [%s]", $client_db, $client_full_type);
			if (exists $implemented{$type}{$client_full_type}) {
				my $params = $implemented{$type}{$client_full_type};
				my $reader = CSVReader->new(
					$file_name,
					$params->{'file_format'},
					$params->{'sep_char'},
				);
				my $emails = $reader->get_all_data();
				$total_email_count += @$emails;
				if (exists $params->{'function'}) {
					$add_email_count += $params->{'function'}->(
						$logger,
						$emails,
						$client_data,
					);

				}
				else {
					$add_email_count += fill_emails(
						$logger,
						$emails,
						$client_data,
						$params->{'candidate'},
						$params->{'adder'},
					);
				}
			}
			else {
				die "importing [$type] is not implemented for [$client_full_type]";
			}

		}
		else {
			die "unknown file name [$file_name]";
		}
	}
	if ($last_client_db) {
		my $result_sql_fn = '_new_email.'.$last_client_db.'.sql';
		$logger->printf("write sql commands to [$result_sql_fn]");
		$data_source->save_sql_commands_to_file($result_sql_fn);
	}

	$logger->print_category_stat();

	$logger->printf("%s/%s emails added", $add_email_count, $total_email_count);

	my $work_time = time() - $start_time;
	$logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
}
else {
	print <<USAGE;
Usage: $0 <file1> [files...]
File names:
	<drname>.patient_emails.csv
	<drname>.responsible_emails.csv
	<drname>.pms_referrings.csv
USAGE
	exit(1);
}

sub fill_emails {
	my ($logger, $emails, $client_data, $candidate_selector, $adder) = @_;

	my $add_email_count = 0;
	for my $email_row (@$emails) {
		my $candidate_manager = CandidateManager->new(
			{
				'by_name_pat_resp' => 1,
				'by_name_resp' => 2,
				'by_name_patient' => 3,
				'by_resp_grouped_by_pats' => 4,
			}
		);
		my $name = $email_row->{'name'};
		my $email = $email_row->{'email'};
		if (Email::Valid->address($email)) {
			my $is_email_exists = $client_data->email_is_used($email);
			if ($is_email_exists) {
				$logger->printf_slow("SKIP [$email]: is already database");
				$logger->register_category('skipped exists');
			}
			else {
				$candidate_selector->(
					$name,
					$client_data,
					$candidate_manager,
				);

				my $candidate = $candidate_manager->get_single_candidate();
				if (defined $candidate) {
					$logger->printf_slow(
						"ADD: %s",
						$email,
					);
					$logger->register_category('added');
					$adder->($email, $candidate, $client_data);
					$add_email_count++;
				}
				else {
					$logger->printf(
						"SKIP: %s (%s) - %s",
						$email,
						$name,
						$candidate_manager->candidates_count_str(),
					);
					$logger->register_category('no candidate found ('.$candidate_manager->candidates_count_str().')');
				}
			}
		}
		else {
			$logger->printf(
				"SKIP: invalid email [%s]",
				$email,
			);
			$logger->register_category('skipped invalid');
		}
	}
	return $add_email_count;
}

sub add_email_with_responsible_patient {
	my ($email, $candidate, $client_data) = @_;

	$client_data->add_email(
		(defined $candidate->{'patient'} ? $candidate->{'patient'}{'PId'} : 0 ),
		$candidate->{'responsible'}{'RId'},
		$email,
		(defined $candidate->{'patient'} ? 0 : 4 ),
		'',
		0,
		'other',
	);
}

sub add_email_to_visitor {
	my ($email, $candidate, $client_data) = @_;

	my $visitor = $candidate;
	$client_data->add_email(
		$visitor->{'id'},
		$email,
		'other',
		join(' ', @$visitor{'FName', 'LName'}),
		'false',
		'other',
	);
}

sub find_patient_ortho_resp {
	my ($name, $client_data, $candidate_manager) = @_;

	my $patients = $client_data->get_patients_by_name($name);
	for my $patient (@$patients) {
		my $responsible_ids = $client_data->get_responsible_ids_by_patient(
			$patient->{'PId'},
		);
		for my $responsible_id (@$responsible_ids) {
			$candidate_manager->add_candidate(
				'by_name_patient',
				{
					'patient' => $patient,
					'responsible' => $client_data->get_responsible_by_id($responsible_id),
				}
			);
		}
	}

}

sub find_patient_by_name {
	my ($name, $client_data, $candidate_manager) = @_;

	my $patients = $client_data->get_patients_by_name($name);
	for my $patient (@$patients) {
		$candidate_manager->add_candidate(
			'by_name_patient',
			$patient,
		);
	}
}

sub find_responsible_by_name {
	my ($name, $client_data, $candidate_manager) = @_;

	my %resp_grouped_by_patients;
	my $responsibles = $client_data->get_responsibles_by_name($name);
	for my $responsible (@$responsibles) {
		$candidate_manager->add_candidate(
			'by_name_resp',
			$responsible,
		);

		my $patients_ids = $client_data->get_patient_ids_by_responsible(
			$responsible->{'RId'},
		);
		my $patients_id_str = join('|', sort @$patients_ids);
		$resp_grouped_by_patients{$patients_id_str} = $responsible;
	}
	## thread responsibles with same patients as same person
	for my $responsible (values %resp_grouped_by_patients) {
		$candidate_manager->add_candidate(
			'by_resp_grouped_by_pats',
			$responsible,
		);
	}
}

sub find_responsible_ortho_resp {
	my ($name, $client_data, $candidate_manager) = @_;

	my $responsibles = $client_data->get_responsible_ids_by_name($name);
	my %resp_grouped_by_patients;
	for my $responsible (@$responsibles) {
		$candidate_manager->add_candidate(
			'by_name_resp',
			{
				'patient' => undef,
				'responsible' => $responsible,
			}
		);
		my $patients_ids = $client_data->get_patient_ids_by_responsible(
			$responsible->{'RId'},
		);
		my $patients = $client_data->get_patients_by_name_and_ids(
			$name,
			undef,
			$patients_ids,
		);
		for my $patient (@$patients) {
			$candidate_manager->add_candidate(
				'by_name_pat_resp',
				{
					'patient' => $patient,
					'responsible' => $responsible,
				},
			);
		}
		my $patients_id_str = join('|', sort @$patients_ids);
		$resp_grouped_by_patients{$patients_id_str} = $responsible;
	}
	## thread responsibles with same patients as same person
	for my $responsible (values %resp_grouped_by_patients) {
		$candidate_manager->add_candidate(
			'by_resp_grouped_by_pats',
			{
				'patient' => undef,
				'responsible' => $responsible,
			}
		);
	}


#	unless (defined $candidate_manager->get_single_candidate()) {
#		find_patient_ortho_resp($name, $client_data, $candidate_manager);
#	}
}

sub add_pms_referrings {
	my ($colleagues, $client_data) = @_;

die "TODO check invalid email";

	my $add_count = 0;
	for my $colleague (@$colleagues) {
		my $colleague_email = $colleague->{'Email'};
		if ($colleague_email =~ m/@/) {
			my $is_colleague_exists = $client_data->email_exists_by_colleague($colleague_email);
			if ($is_colleague_exists) {
				print "SKIP [$colleague_email]: already exists in database\n";
			}
			else {
	            print "ADD [$colleague_email]\n";
				$client_data->add_colleague(
					$colleague->{'FName'},
					$colleague->{'LName'},
					$colleague_email,
					generate_password(),
				);
				$add_count++;
			}
		}
		else {
			print "SKIP [$colleague_email]: is not email\n";
		}
	}
	return $add_count;
}

#sub add_colleagues {
#    my ($colleagues, $client_data) = @_;
#
#    my $add_count = 0;
#    for my $colleague (@$colleagues) {
#        my $colleague_name = $colleague->{'name'};
#        my $colleague_email = $colleague->{'email'};
#        my $is_colleague_exists = $client_data->is_colleague_exists($colleague_email);
#        if ($is_colleague_exists) {
#            print "SKIP [$colleague_email]: already exists in database\n";
#        }
#        else {
#            my @parts = get_name_parts($colleague_name);
#            if (@parts) {
#                print "ADD [$colleague_email]\n";
#                $client_data->add_colleague(
#                    $parts[0],
#                    $parts[1],
#                    $colleague_email,
#                    generate_password(),
#                );
#                $add_count++;
#            }
#            else {
#                print "SKIP [$colleague_name]: can't parse name\n";
#            }
#        }
#    }
#    return $add_count;
#}

#sub add_email_to_responsibles_dental {
#    my ($client_data, $responsibles) = @_;
#
#    my $add_count = 0;
#    for my $resp (@$responsibles) {
#        my $responsible_name = $resp->{'name'};
#        my $responsible_email = $resp->{'email'};
#        my $is_email_exists = $client_data->email_is_used($responsible_email);
#        if ($is_email_exists) {
#            print "SKIP [$responsible_email]: already exists in database\n";
#        }
#        else {
#            my $found_responsibles = $client_data->find_responsible_by_name($responsible_name);
#            if (@$found_responsibles == 1) {
#                my $found_resp = $found_responsibles->[0];
#                my $found_patients = $client_data->get_patients_by_responsible( $found_resp->{'RId'} );
#                $add_count += add_email_to_patient_list(
#                    $client_data,
#                    "patients for responsible [$responsible_name]",
#                    $responsible_email,
#                    $found_patients,
#                    [
#                        sub {
#                            my ($found_pat) = @_;
#                            my $name = $found_pat->{'FName'}.' '.$found_pat->{'LName'};
#                            return $responsible_name =~ m/\Q$name/;
#                        }
#                    ],
#                );
#            }
#            elsif (@$found_responsibles == 0) {
#                print "SKIP [$responsible_email]: responsible [$responsible_name] is not found\n";
#            }
#            else {
#                my @rids = map {$_->{'RId'}} @$found_responsibles;
#                print "SKIP [$responsible_email]: too many responsibles found [$responsible_name]: ".join(', ', @rids)."\n";
#            }
#        }
#    }
#    return $add_count;
#}
#
#sub add_email_to_patients_dental {
#    my ($client_data, $patients) = @_;
#
#    my $add_count = 0;
#    for my $pat (@$patients) {
#        my $patient_name = $pat->{'name'};
#        my $patient_email = $pat->{'email'};
#        my $is_email_exists = $client_data->email_is_used($patient_email);
#        if ($is_email_exists) {
#            print "SKIP [$patient_email]: already exists in database\n";
#        }
#        else {
#            my $found_patients = $client_data->find_patients_by_name($patient_name);
#            $add_count += add_email_to_patient_list(
#                $client_data,
#                "patient [$patient_name]",
#                $patient_email,
#                $found_patients,
#                [
#                    sub {
#                        my ($found_pat) = @_;
#
#                        return $client_data->count_ledgers_by_patient( $found_pat->{'PId'} );
#                    }
#                ],
#            );
#        }
#    }
#    return $add_count;
#}
#
#sub add_email_to_patient_list {
#    my ($client_data, $message_prefix, $patient_email, $found_patients, $patient_compare) = @_;
#
#    my $add_count = 0;
#    if (@$found_patients == 1) {
#        my $patient = $found_patients->[0];
#        $client_data->add_email(
#            $patient->{'PId'},
#            $patient->{'RId'},
#            $patient_email,
#        );
#        print "ADD [$patient_email]: $message_prefix to [".$patient->{'PId'}."]\n";
#        $add_count++;
#    }
#    elsif (@$found_patients == 0) {
#        print "SKIP [$patient_email]: $message_prefix is not found\n";
#    }
#    else {
#        my $added = 0;
#        for my $cond (@$patient_compare) {
#            my @patients_with_cond;
#            my @patients_without_cond;
#            for my $found_pat (@$found_patients) {
#                if ($cond->($found_pat)) {
#                    push( @patients_with_cond, $found_pat );
#                }
#                else {
#                    push( @patients_without_cond, $found_pat );
#                }
#            }
#            if (@patients_with_cond == 1) {
#                my $patient = $patients_with_cond[0];
#                $client_data->add_email(
#                    $patient->{'PId'},
#                    $patient->{'RId'},
#                    $patient_email,
#                );
#                print "ADD [$patient_email]: $message_prefix to [".$patient->{'PId'}."]\n";
#                $add_count++;
#                $added = 1;
#                last;
#            }
#        }
#        unless ($added) {
#            my @pids = map {$_->{'PId'}} @$found_patients;
#            print "SKIP [$patient_email]: $message_prefix found too many: ".join(', ', @pids)."\n";
#        }
#    }
#    return $add_count;
#}




sub get_name_parts {
	my ($name) = @_;

	$name =~ s/^dr\.?\s+//i;
	my @parts = split(/\s+/, $name);
	if (@parts != 2 && $name =~ m/\|/) {
		@parts = split(/\|/, $name);
	}
	if (@parts == 2) {
		return map {trim($_)} @parts;
	}
	else {
		return;
	}
}

sub trim {
	my ($str) = @_;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}

sub generate_password {
    my @symbols = split(//, "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ123456789");

    return join('', map {$symbols[int(rand()*@symbols)]} 0..7);
}


