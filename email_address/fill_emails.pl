## $Id$
use strict;
use warnings;

use lib qw( ../lib );

use CandidateManager;
use CSVReader;
use DataSource::DB;


my @files = @ARGV;
if (@files) {
	my $start_time = time();
	my $add_email_count = 0;
	my $total_email_count = 0;

	my %implemented = (
		'patient_emails' => {
			'ortho_resp' => {
				'candidate' => \&find_patient_ortho_resp,
				'file_format' => ['name', 'email'],
			},
#			'dental' => \&add_email_to_patients_dental,
		},
		'responsible_emails' => {
			'ortho_resp' => {
				'candidate' => \&find_responsible_ortho_resp,
				'file_format' => ['name', 'email'],
			}
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
	my $last_client_db = undef;
	for my $file_name (@files) {
		if ($file_name =~ m/^(.*)\.(.*)\.(.*)$/) {
			my ($client_db, $type, $ext) = ($1, $2, $3);
			$client_db =~ s/^_//;
			$last_client_db = $client_db;

			my $client_data = $data_source->get_client_data_by_db($client_db);
			$client_data->set_strict_level(0);
			printf "database source: client [%s]\n", $client_db;

			my $client_full_type = $client_data->get_full_type();
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
						$emails,
						$client_data,
					);

				}
				else {
					$add_email_count += fill_emails(
						$emails,
						$client_data,
						$params->{'candidate'},
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
		printf("write sql commands to [$result_sql_fn]\n");
		$data_source->save_sql_commands_to_file($result_sql_fn);
	}

	print "$add_email_count/$total_email_count emails added\n";
	printf "done: %.2f minutes\n", (time() - $start_time) / 60;
} else {
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
	my ($emails, $client_data, $candidate_selector) = @_;

	my $add_email_count = 0;
	for my $email_row (@$emails) {
		my $candidate_manager = CandidateManager->new(
			{
				'by_name_pat_resp' => 1,
				'by_name_resp' => 2,
				'by_name_patient' => 3,
			}
		);
		my $name = $email_row->{'name'};
		my $email = $email_row->{'email'};
		my $is_email_exists = $client_data->email_is_used($email);
		if ($is_email_exists) {
			print "SKIP [$email]: is already database\n";
		}
		else {
			$candidate_selector->(
				$name,
				$client_data,
				$candidate_manager,
			);

			my $candidate = $candidate_manager->get_single_candidate();
			if (defined $candidate) {
				printf(
					"ADD: %s\n",
					$email,
				);
				$client_data->add_email(
					(defined $candidate->{'patient'} ? $candidate->{'patient'}{'PId'} : 0 ),
					$candidate->{'responsible'}{'RId'},
					$email,
					(defined $candidate->{'patient'} ? 0 : 4 ),
					'',
					0,
					'other',
				);
				$add_email_count++;
			}
			else {
				printf(
					"SKIP: %s - %s\n",
					$email,
					$candidate_manager->candidates_count_str(),
				);
			}
		}
	}
	return $add_email_count;
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


sub find_responsible_ortho_resp {
	my ($name, $client_data, $candidate_manager) = @_;

	my $responsibles = $client_data->get_responsible_ids_by_name($name);
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
	}
#	unless (defined $candidate_manager->get_single_candidate()) {
#		find_patient_ortho_resp($name, $client_data, $candidate_manager);
#	}
}

sub add_pms_referrings {
	my ($colleagues, $client_data) = @_;

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



#package DBSource;
#
#use DBI;
#
#
#sub new {
#    my ($class, $db_name) = @_;
#
#    require Sesame::Unified::Client;
#
#    my $client_ref = Sesame::Unified::Client->new('db_name', $db_name);
#
#    my $dbh = get_connection( $db_name );
#    my ($type, $id) = ( $client_ref->get_id() =~ m/(\w)(\d+)/ );
#
#    return bless {
#        'dbh'     => $dbh,
#        'db_name' => $db_name,
#        'insert_commands' => [],
#    }, $class;
#}
#
#sub get_insert_commands {
#    my ($self) = @_;
#
#    return $self->{'insert_commands'};
#}
#
#
#sub get_db_name {
#    my ($self) = @_;
#
#    return $self->{'db_name'};
#}
#
#sub _insert {
#    my ($self, $insert_cmd) = @_;
#
#    $self->{'dbh'}->do($insert_cmd);
#    push( @{ $self->{'insert_commands'} }, $insert_cmd );
#}
#
#
#sub get_patients_by_responsible {
#    my ($self, $rid) = @_;
#
#    my $patients = $self->{'dbh'}->selectall_arrayref(
#        "SELECT PId, RId, FName, LName, Active FROM Patients WHERE RId=?",
#        { 'Slice' => {} },
#        $rid
#    );
#}
#
#sub find_patients_by_name {
#    my ($self, $name) = @_;
#
#    my $patients = $self->{'dbh'}->selectall_arrayref(
#        "SELECT PId, RId, FName, LName, Active FROM Patients WHERE CONCAT(FName, ' ', LName)=?",
#        { 'Slice' => {} },
#        $name
#    );
#    unless (@$patients) {
#        $patients = $self->{'dbh'}->selectall_arrayref(
#            "SELECT PId, RId, FName, LName, Active FROM Patients WHERE ? LIKE CONCAT('%', FName, ' ', LName,'%')",
#            { 'Slice' => {} },
#            $name
#        );
#    }
#    return $patients;
#}
#
#sub find_responsible_by_name {
#    my ($self, $name) = @_;
#
#    my $responsibles = $self->{'dbh'}->selectall_arrayref(
#        "SELECT RId, FName, LName FROM Responsibles WHERE CONCAT(FName, ' ', LName)=?",
#        { 'Slice' => {} },
#        $name
#    );
#    unless (@$responsibles) {
#        $responsibles = $self->{'dbh'}->selectall_arrayref(
#            "SELECT RId, FName, LName FROM Responsibles WHERE ? LIKE CONCAT('%', FName, ' ', LName,'%')",
#            { 'Slice' => {} },
#            $name
#        );
#    }
#    return $responsibles;
#}
#


#sub count_ledgers_by_patient {
#    my ($self, $pid) = @_;
#
#    return scalar $self->{'dbh'}->selectrow_array(
#        "SELECT count(*) FROM Ledgers WHERE PId=?",
#        undef,
#        $pid,
#    );
#}
#
### static
#sub is_client_exists {
#    my ($class, $db_name) = @_;
#
#    my $dbh = get_connection();
#    return $db_name eq $dbh->selectrow_array("SHOW DATABASES LIKE ?", undef, $db_name);
#}
#
#sub get_connection {
#    my ($db_name) = @_;
#
#    $db_name ||= '';
#
#    return DBI->connect(
#        "DBI:mysql:host=$ENV{SESAME_DB_SERVER}".($db_name?";database=$db_name":""),
#        'admin',
#        'higer4',
#        {
#            'RaiseError' => 1,
#            'ShowErrorStatement' => 1,
#            'PrintError' => 0,
#        }
#    );
#}
