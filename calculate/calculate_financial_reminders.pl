#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use List::Util qw( first maxstr minstr );

use lib qw(../lib);

use CandidateManager;
use CSVWriter;
use DataSource::DB;
use DateUtils;

use constant 'FINANCIAL_REMINDER_TYPE' => 2;

my @clients = @ARGV;
if (@clients) {
	my $data_source = DataSource::DB->new();
	my $start_time = time();
	my $result_file = '_result.csv';
	printf "writing result to [%s]\n", $result_file;
	my $output = CSVWriter->new(
		$result_file,
#		[ 'username', 'description', 'type', 'count' ],
		[
			'username',
			'is active',
			'financial reminder enabled',
			'online payment enabled',
			'patient id',
			'patient is active',
			'patient email count',
			'appointment',
			'app paid online',
			'app paid insurance',
			'app paid card',
			'app paid check',
			'app paid other',
			'app with financial reminder',
			'paid online N days after rem',
			'first online payment date',
			'last online payment date',
			'first financial reminder date',
			'last financial reminder date',
		],
	);
	for my $client_identity (@clients) {
		my $client_data = $data_source->get_client_data_by_db($client_identity);
		printf "database source: client [%s]\n", $client_identity;
#		my $data = get_unique_description($client_data);
		my $data = get_report($client_data);
		$output->write_data($data);
	}
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 <database1> [database2...]\n";
	exit(1);
}

sub get_unique_description {
	my ($client_data) = @_;

	my $unique_descriptions = $client_data->get_unique_ledgers_description_by_type('P');
	my %cleared_unique_desc;
	for my $description (@$unique_descriptions) {
		my $clear_desc = clear_payment_description($description->{'Description'});
		if (exists $cleared_unique_desc{$clear_desc}) {
			$cleared_unique_desc{$clear_desc} += $description->{'Count'};
		}
		else {
			$cleared_unique_desc{$clear_desc} = $description->{'Count'};
		}
	}
	return [
		sort {
			$a->{'description'} cmp $b->{'description'}
		}
		map {
			{
				'username' => $client_data->get_db_name(),
				'description' => $_,
				'type' => (get_payment_type_by_descrition($_) || ''),
				'count' => $cleared_unique_desc{$_},
			}
		}
		keys %cleared_unique_desc
	];
}



sub get_report {
	my ($client_data) = @_;

	my $reminder_settings = $client_data->get_email_reminder_settings();
	my $financial_reminder_setting = first { $_->{'type'} eq 'financial' } @$reminder_settings;
	my $ccp_id = $client_data->get_ccp_id();

	my %unique_patient_names;
	for my $pat (@{ $client_data->get_all_patients() }) {
		$unique_patient_names{ $pat->{'FName'} }{ $pat->{'LName'} } = $pat;
	}

    my $date_interval = $client_data->get_ledgers_date_interval();
    unless ( defined $date_interval ) {
    	$date_interval = {
    		'min' => DateUtils->get_last_year_date_mysql(),
    		'max' => DateUtils->get_current_date_mysql(),
    	};
    }
    my $last_year = DateUtils->get_last_year_date_mysql();
    if ($last_year gt $date_interval->{'min'}) {
    	$date_interval->{'min'} = $last_year;
    }

	my @payment_priority = ('online', 'insurance', 'card', 'check', 'money');

	my $count_financial_reminder_sent = $client_data->count_sent_emails_by_type(FINANCIAL_REMINDER_TYPE);
	printf "[%d] financial reminders sent\n", $count_financial_reminder_sent;

	my $patients = $client_data->get_all_patients();

#	$patients = [];
#	$appointments_stat{'financial'} = $count_financial_reminder_sent;

	my @data;
	my $processed_patients = 0;
	for my $patient (@$patients) {
		my $email_count = $client_data->count_emails_by_pid($patient->{'PId'});
		my $appointments_intervals = get_appointments_intervals(
			$client_data,
			$patient->{'PId'},
			$date_interval,
		);
		my $payments = get_payments_within_intervals(
			$client_data,
			$patient->{'PId'},
			$appointments_intervals,
		);
		my $financial_reminders = ($count_financial_reminder_sent ?
			get_financial_reminders_within_intervals(
				$client_data,
				$patient->{'PId'},
				$appointments_intervals,
			) :
			{}
		);
		my $cc_payments = ($ccp_id ?
			get_cc_payments_within_interval(
				$client_data,
				$patient->{'PId'},
				$appointments_intervals,
			) :
			{}
		);
		for my $interval (@$appointments_intervals) {
			my %appointments_stat = map {$_ => ''} (@payment_priority);

			my $cc_payment         = $cc_payments->{ $interval->{'Date'} };
			my $financial_reminder = $financial_reminders->{ $interval->{'Date'} };
			my $diff_days = '';

			my $payment_type = $payments->{ $interval->{'Date'} };
			if (defined $cc_payment) {
				## online payment found
				$payment_type->{'online'} = $cc_payment->{'Count'};
			}
			for my $type (@payment_priority) {
				if ($payment_type->{$type}) {
					$appointments_stat{$type} = 1;
					last;
				}
			}

			if (defined $financial_reminder) {
				if (defined $cc_payment) {
					$diff_days = DateUtils->date_diff_in_days(
						$cc_payment->{'FirstDate'},
						$financial_reminder->{'FirstDate'},
					);
				}
				else {
					## no online payment
				}
			}
			else {
				## no financial reminder
			}
			push(
				@data,
				{
					'username'                       => $client_data->get_db_name(),
					'is active'                      => $client_data->is_active(),
					'financial reminder enabled'     => (defined $financial_reminder_setting ? $financial_reminder_setting->{'is_enabled'} : 0),
					'online payment enabled'         => ($ccp_id ? 1 : 0),
					'patient id'                     => $patient->{'PId'},
					'patient is active'              => $patient->{'Active'},
					'patient email count'            => $email_count,
					'appointment'                    => $interval->{'Date'},
					'app paid online'                => $appointments_stat{'online'},
					'app paid insurance'             => $appointments_stat{'insurance'},
					'app paid card'                  => $appointments_stat{'card'},
					'app paid check'                 => $appointments_stat{'check'},
					'app paid other'                 => $appointments_stat{'money'},
					'app with financial reminder'    => defined $financial_reminder,
					'paid online N days after rem'   => $diff_days,
					'first online payment date'      => (defined $cc_payment ? $cc_payment->{'FirstDate'} : ''),
					'last online payment date'       => (defined $cc_payment ? $cc_payment->{'LastDate'} : ''),
					'first financial reminder date'  => (defined $financial_reminder ? $financial_reminder->{'FirstDate'} : ''),
					'last financial reminder date'   => (defined $financial_reminder ? $financial_reminder->{'LastDate'} : ''),
				}
			);
		}
		if (!(++$processed_patients%1000)) {
			printf "[%d] patients processed\n", $processed_patients;
		}
	}
	printf "[%d] patients processed\n", $processed_patients;

	return \@data;
}

sub get_financial_reminders_within_intervals {
	my ($client_data, $pid, $date_interval) = @_;

    ## 2 | financial
    my %reminders_sent;
	my $financial_reminders = $client_data->get_sent_emails_by_pid_type($pid, FINANCIAL_REMINDER_TYPE);
	for my $rem (@$financial_reminders) {
		my $start_date = find_start_date_in_intervals(
			$rem->{'DateTime'},
			$date_interval,
		);
		if (defined $start_date) {
			if (exists $reminders_sent{$start_date}) {
				merge_event($reminders_sent{$start_date}, $rem);
			}
			else {
				$reminders_sent{$start_date} = {
					'Count' => 1,
					'FirstDate' => $rem->{'DateTime'},
					'LastDate'  => $rem->{'DateTime'},
				};
			}
		}
	}
	return \%reminders_sent;
}

sub merge_event {
	my ($current_data, $new_data) = @_;

	$current_data->{'Count'} ++;
	$current_data->{'FirstDate'} = minstr(
		$current_data->{'FirstDate'},
		$new_data->{'DateTime'},
	);
	$current_data->{'LastDate'} = maxstr(
		$current_data->{'LastDate'},
		$new_data->{'DateTime'},
	);

}

sub find_start_date_in_intervals {
	my ($date, $intervals) = @_;

	die "wrong [$date]" unless length $date == 19;
	for my $interval (@$intervals) {
		if ($interval->{'Date'}.' 00:00:00' le $date && $date lt $interval->{'EndDate'}.' 00:00:00') {
			return $interval->{'Date'};
		}
	}
	return undef;
}

sub get_appointments_intervals {
	my ($client_data, $pid, $date_interval) = @_;

	my $appointments = $client_data->get_appointments_by_pid($pid);

	if (@$appointments) {
		my %search_end;
		## find next appointment date for all appointments
		for my $app_index (1..@$appointments) {
			my $start = $appointments->[ $app_index-1 ]{'Date'};
			my $end = (
				$app_index == @$appointments ?
					$date_interval->{'max'} :
					$appointments->[ $app_index ]{'Date'}
			);
			$search_end{ $start } = $end;
		}

		## filter appointments by date interval
		@$appointments =
			map {
				{
					'Date' => $_->{'Date'},
					'EndDate' => $search_end{ $_->{'Date'} },
					#'PId' => $_->{'PId'},
				}
			}
			grep {
				$_->{'Date'} ge $date_interval->{'min'} &&
				$_->{'Date'} le $date_interval->{'max'}
			}
			@$appointments;

	}
	return $appointments;
}

sub get_payments_within_intervals {
	my ($client_data, $pid, $appointments_intervals) = @_;

	my %payments;
	my $accounts = $client_data->get_accounts_by_pid($pid);
	for my $app_interval (@$appointments_intervals) {
		my %payment_types;
		for my $account (@$accounts) {
			my $ledgers = $client_data->get_ledgers_by_account_date_interval(
				$account->{'AccountId'},
				$app_interval->{'Date'},
				$app_interval->{'EndDate'},
			);
			if ($account->{'IId'}) {
				## insurance payments
				my ($payment_count) = get_payments($ledgers);
				$payment_types{'insurance'} += $payment_count;
			}
			else {
				append_payment_type(\%payment_types, $ledgers)
			}
		}
		$payments{ $app_interval->{'Date'} } = \%payment_types;
#			printf(
#				"PAT %s APP %s - CC:%d CH:%d I:%d M:%d \n",
#				$app->{'PId'},
#				$app->{'Date'},
#				($payment_types{'card'} || 0),
#				($payment_types{'check'} || 0),
#				($payment_types{'insurance'} || 0),
#				($payment_types{'money'} || 0),
#			);
	}
	return \%payments;
}

sub get_cc_payments_within_interval {
	my ($client_data, $pid, $appointments_intervals) = @_;

	my $cc_payments = get_cc_payments_by_pid($client_data, $pid);
	my %payments;
	if (defined $cc_payments) {
		for my $payment (@$cc_payments) {
			my $start_date = find_start_date_in_intervals(
				$payment->{'DateTime'},
				$appointments_intervals,
			);
			if (defined $start_date) {
				if (exists $payments{$start_date}) {
					merge_event($payments{$start_date}, $payment);
				}
				else {
					$payments{$start_date} = {
						'Count' => 1,
						'FirstDate' => $payment->{'DateTime'},
						'LastDate' => $payment->{'DateTime'},
					};
				}
			}
		}
	}
	return \%payments;
}

sub get_cc_payments_by_pid {
	my ($client_data, $pid) = @_;

	my $patient_cc_payment = $client_data->get_cached_data(
		'patient_cc_payment',
		sub {
			my %patient_payments;
			my $payments = $client_data->get_complete_cc_payments();
			for my $payment (@$payments) {
				my $candidate_manager = CandidateManager->new(
					{
						'comment' => 1,
						'email' => 2,
						'name' => 3,
					}
				);
				get_patient_candidates_for_payment(
					$client_data,
					$payment,
					$candidate_manager,
				);
				my $pid = $candidate_manager->get_single_candidate();
				if (defined $pid) {
#					printf(
#						"patient payment found [%s]\n",
#						$pid,
#					);
					push(
						@{ $patient_payments{ $pid } },
						$payment,
					);
				}
				else {
					printf(
						"can't find patient by payment [%s]\n",
						join('-',
							map {$payment->{$_}}
							grep {$payment->{$_}}
							('FName', 'LName', 'Comment', 'Email')
						),
					);
				}
			}
			return \%patient_payments;
		}
	);

	return $patient_cc_payment->{$pid};
}

sub get_patient_candidates_for_payment {
	my ($client_data, $payment, $candidate_manager) = @_;

	my $comment = ($payment->{'Comment'} || '');
	$comment =~ s/\s+$//;
	if (length $comment) {
		for my $patient (@{ $client_data->get_patients_by_name($comment) }) {
			$candidate_manager->add_candidate('comment', $patient->{'PId'});
		}
	}
	for my $patient (@{ $client_data->get_patients_by_name($payment->{'FName'}, $payment->{'LName'}) }) {
		$candidate_manager->add_candidate('name', $patient->{'PId'});
	}
}

sub get_payments {
	my ($ledgers) = @_;

	my @payments = grep {uc $_->{'Type'} eq 'P'} @$ledgers;
	my %unique_desc = map {clear_payment_description($_) => 1} @payments;
	return ( scalar @payments, \%unique_desc );
}

sub get_insurances {
	my ($ledgers) = @_;

	my @insurances = grep {uc $_->{'Type'} eq 'I'} @$ledgers;
	return scalar @insurances;
}

sub clear_payment_description {
	my ($str) = @_;

	$str =~ s/;/,/g;
	$str =~ s/\d//g;
	$str =~ s/\([^)]*\)//g;
	$str =~ s/\W+$//;
	$str =~ s/^\W+//;
	if ($str =~ m/:/) {
		($str, undef) = split(m/:/, $str, 2);
	}
	## normalize spaces
	$str =~ s/\s+/ /g;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return lc $str;
}

{
	my $key_words;

	sub get_payment_type_by_descrition {
		my ($description) = @_;

		unless (defined $key_words) {
			$key_words = [
				[ qr'\binsurance\b'                => 'insurance', ],
				[ qr'\binsur\b'                    => 'insurance', ],
				[ qr'\bins\b'                      => 'insurance', ],
				[ qr'\bam(?:er)?\W+express\b'      => 'card', ],
				[ qr'\bam(?:er)?\W+exp\b'          => 'card', ],
				[ qr'\bam(?:er)?\W+ex\b'           => 'card', ],
				[ qr'\bamerex\b'                   => 'card', ],
				[ qr'\bamexp?\b'                   => 'card', ],
				[ qr'\bamx\b'                      => 'card', ],
				[ qr'\bamexpress?\b'               => 'card', ],
				[ qr'\bamerican\W+exp(?:ress?)?\b' => 'card', ],
				[ qr'\bdiscovery?\b'               => 'card', ],
				[ qr'\bdiscv?e?r?\b'               => 'card', ],
				[ qr'\bdd\b'                       => 'card', ],
				[ qr'\bmc\b'                       => 'card', ],
				[ qr'\bmcard\b'                    => 'card', ],
				[ qr'\bmast(?:card)?\b'            => 'card', ],
				[ qr'\bmas?ter(?:card)?\b'         => 'card', ],
				[ qr'\bcard\b'                     => 'card', ],
				[ qr'^credit ca?rd'                => 'card', ],
				[ qr'\bmc\b'                       => 'card', ],
				[ qr'\bm/c\b'                      => 'card', ],
				[ qr'\bm/card\b'                   => 'card', ],
				[ qr'\bvisa\b'                     => 'card', ],
				[ qr'\bvisac(?:ard)?\b'            => 'card', ],
				[ qr'\bcheck\b'                    => 'check', ],
				[ qr'\bcks\b'                      => 'check', ],
				[ qr'\bchk\b'                      => 'check', ],
				[ qr'\bck\b'                       => 'check', ],
				[ qr'\back\b'                      => 'check', ],
			];
		}

		$description = lc $description;
		for my $word (@$key_words) {
			if ($description =~ m/$word->[0]/) {
				return $word->[1];
			}
		}
		return undef;
	}
}


sub append_payment_type {
	my ($types, $ledgers) = @_;

	for my $l (grep {uc $_->{'Type'} eq 'P'} @$ledgers) {
		my $type = get_payment_type_by_descrition($l->{'Description'});
		if (defined $type) {
			$types->{$type} ++;
		}
		else {
			$types->{'money'} ++;
		}
	}
}

sub get_ledgers_stat {
    my ($ledgers) = @_;

    my $sum = 0;
    my %sum_by_type;
    my %last_payment_date;
    my %first_payment_date;
    my %types;
    my %providers;
    for my $l (@$ledgers) {
        $types{ $l->{'Type'} } = 1;
        if (exists $l->{'Provider'}) {
            $providers{ $l->{'Provider'} } = 1;
        }
        if ($l->{'Amount'} != 0) {
            $sum += $l->{'Amount'};
            $sum_by_type{ $l->{'Type'} } += $l->{'Amount'};
            $last_payment_date{ $l->{'Type'} } = substr($l->{'DateTime'}, 0, 10);
            unless (exists $first_payment_date{ $l->{'Type'} }) {
                $first_payment_date{ $l->{'Type'} } = substr($l->{'DateTime'}, 0, 10);
            }
        }
    }
    return {
        'sum' => $sum,
        'types' => [ sort keys %types ],
        'providers' => [ sort keys %providers ],
        'sum_by_type' => \%sum_by_type,
        'last_payment_date' => \%last_payment_date,
        'first_payment_date' => \%first_payment_date,
    };
}

