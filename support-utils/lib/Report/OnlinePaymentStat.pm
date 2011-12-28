## $Id$
package Report::OnlinePaymentStat;

use strict;
use warnings;

use List::Util qw( first min );

use lib '..';

use CandidateManager;
use DateUtils;

use constant 'FINANCIAL_REMINDER_TYPE' => 2;

my $PATIENT_ID = 'patient id';
my $DAYS_FROM_FINANCIAL = 'days from last financial reminder';


sub get_columns {
	my ($class) = @_;

	return [
		'username',
		'is active',
		'financial reminder enabled',
		'online payment enabled',
		$PATIENT_ID,
		'payment date',
		$DAYS_FROM_FINANCIAL,
	];
}

sub generate_report {
	my ($class, $client_data, $logger) = @_;

	my @data;
	my %patient_cache;
	my $payments = $client_data->get_complete_cc_payments();
	for my $payment (@$payments) {
		my $payment_str = sprintf(
			"payment: first name [%s], last name [%s], email [%s], comment [%s]",
			$payment->{'FName'},
			$payment->{'LName'},
			$payment->{'Email'} // '',
			$payment->{'Comment'} // '',
		);

		my $data = undef;
		unless (exists $patient_cache{$payment_str}) {
			my $candidate_manager = $class->get_patient_candidates_for_payment(
				$client_data,
				$payment,
			);
			$patient_cache{$payment_str} = $candidate_manager->get_single_candidate();
		}
		my $pid = $patient_cache{$payment_str};
		if (defined $pid) {
			$data = $class->process_payment_for_patient($logger, $client_data, $pid, $payment);
			$logger->register_category('payments with patient');
			$logger->printf_slow(
				"%s: patient [%s] is found for %s",
				$client_data->get_username(),
				$pid,
				$payment_str,
			);
		}
		else {
			my $candidate_manager = $class->get_responsible_candidates_for_payment(
				$client_data,
				$payment,
			);
			my $rid = $candidate_manager->get_single_candidate();
			if (defined $rid) {
				$data = $class->process_payment_for_responsible($logger, $client_data, $rid, $payment);
				$logger->register_category('payments with resposible');
				$logger->printf_slow(
					"%s: responsible [%s] is found for %s",
					$client_data->get_username(),
					$rid,
					$payment_str,
				);
			}
			else {
				$logger->printf(
					"%s: can't find patient by %s",
					$client_data->get_username(),
					$payment_str,
				);
				$logger->register_category('no patient or responsible for payment found');
			}
		}
		if (defined $data) {
			$data->{'username'}  = $client_data->get_db_name();
			$data->{'is active'} = $client_data->is_active();
			$data->{'financial reminder enabled'} = ($class->is_financial_reminder_enabled($client_data)),
			$data->{'online payment enabled'}     = ($client_data->is_ccp_enabled() ? 1 : 0),
			push(@data, $data);
		}
	}
	return $class->group_by_patient(\@data);
}

sub group_by_patient {
	my ($class, $data) = @_;

	my %data;
	for my $row (@$data) {
		if (exists $data{ $row->{$PATIENT_ID} }) {
			my $current = $data{ $row->{$PATIENT_ID} };
			if (length $row->{$DAYS_FROM_FINANCIAL}) {
				if (length $current->{$DAYS_FROM_FINANCIAL}) {
					if ($row->{$DAYS_FROM_FINANCIAL} < $current->{$DAYS_FROM_FINANCIAL}) {
						$current = $row;
					}
				} else {
					$current = $row;
				}
			}
			$data{ $row->{$PATIENT_ID} } = $current;
		}
		else {
			$data{ $row->{$PATIENT_ID} } = $row;
		}
	}

	return [ values %data ];
}

sub is_financial_reminder_enabled {
	my ($class, $client_data) = @_;

	my $reminder_settings = $client_data->get_email_reminder_settings();
	my $financial_reminder_setting = first { $_->{'type'} eq 'financial' } @$reminder_settings;
	return (defined $financial_reminder_setting ? $financial_reminder_setting->{'is_enabled'} : 0)
}

sub process_payment_for_responsible {
	my ($class, $logger, $client_data, $rid, $payment) = @_;

	my $day_count = undef;
	my $pid_found = undef;
	for my $pid ($client_data->get_patient_ids_by_responsible($rid)) {
		my $financial_reminders = $client_data->get_sent_emails_by_pid_type($pid, FINANCIAL_REMINDER_TYPE);
		for my $rem (@$financial_reminders) {
			my $diff = DateUtils->date_diff_in_days(
				$payment->{'DateTime'},
				$rem->{'DateTime'},
			);
			if ($diff >= 0) {
				if (defined $day_count) {
					$day_count = min($day_count, $diff);
				} else {
					$day_count = $diff;
				}
			}
			if (!defined $pid_found || $diff == $day_count) {
				$pid_found = $pid;
			}
		}
	}

	return {
		$PATIENT_ID => $pid_found // '',
		'payment date' => $payment->{'DateTime'},
		$DAYS_FROM_FINANCIAL => $day_count // '',
	};
}

sub process_payment_for_patient {
	my ($class, $logger, $client_data, $pid, $payment) = @_;

	my $financial_reminders = $client_data->get_sent_emails_by_pid_type($pid, FINANCIAL_REMINDER_TYPE);
	my $day_count = undef;
	for my $rem (@$financial_reminders) {
		my $diff = DateUtils->date_diff_in_days(
			$payment->{'DateTime'},
			$rem->{'DateTime'},
		);
		if ($diff >= 0) {
			if (defined $day_count) {
				$day_count = min($day_count, $diff);
			} else {
				$day_count = $diff;
			}
		}
	}

	return {
		$PATIENT_ID => $pid,
		'payment date' => $payment->{'DateTime'},
		$DAYS_FROM_FINANCIAL => $day_count // '',
	};
}

sub get_responsible_candidates_for_payment {
	my ($class, $client_data, $payment) = @_;

	my $candidate_manager = CandidateManager->new(
		{
			'email' => 1,
			'name' => 2,
		}
	);
	for my $responsible (@{ $client_data->get_responsibles_by_name($payment->{'FName'}, $payment->{'LName'}) }) {
		$candidate_manager->add_candidate('name', $responsible->{'RId'});
	}

	if ($payment->{'Email'}) {
		my $visitor_ids = $client_data->get_visitor_ids_by_email($payment->{'Email'});
		for my $visitor_id (@$visitor_ids) {
			my $responsible = $client_data->get_responsible_by_id($visitor_id);
			if (defined $responsible) {
				$candidate_manager->add_candidate('email', $responsible->{'RId'});
			}
		}
	}
	return $candidate_manager;
}

sub get_patient_candidates_for_payment {
	my ($class, $client_data, $payment) = @_;

	my $candidate_manager = CandidateManager->new(
		{
			'comment' => 1,
			'name' => 2,
			'name_and_email' => 3,
			'email' => 4,
			'responsible_name' => 5,
		}
	);

	my $comment = ($payment->{'Comment'} || '');
	$comment =~ s/\s+$//;
	if (length $comment) {
		for my $patient (@{ $client_data->get_patients_by_name($comment) }) {
			$candidate_manager->add_candidate('comment', $patient->{'PId'});
		}
	}
	for my $patient (@{ $client_data->get_patients_by_name($payment->{'FName'}, $payment->{'LName'}) }) {
		$candidate_manager->add_candidate('name', $patient->{'PId'});
		for my $email (@{ $client_data->get_emails_by_pid($patient->{'PId'}) }) {
			if (lc $email->{'Email'} eq lc $payment->{'Email'}) {
				$candidate_manager->add_candidate('name_and_email', $patient->{'PId'});
			}
		}
	}
	for my $responsible (@{ $client_data->get_responsibles_by_name($payment->{'FName'}, $payment->{'LName'}) }) {
		for my $patient_id (@{ $client_data->get_patient_ids_by_responsible($responsible->{'RId'}) }) {
			$candidate_manager->add_candidate('responsible_name', $patient_id);
		}
	}
	return $candidate_manager;
}


1;
