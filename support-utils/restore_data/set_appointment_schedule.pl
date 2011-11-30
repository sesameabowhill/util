#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use Getopt::Long;

use lib '../lib';

use DataSource::DB;
use DateUtils;
use Logger;

my ($weekday, $allow_today_appointments);
GetOptions(
	'resend-weekday=i'  => \$weekday,
	'allow-today-appointments!'  => \$allow_today_appointments,
);

my (@clients) = @ARGV;
if (@clients) {
	$|=1;
	my $logger = Logger->new();
	my $start_time = time();
	my $data_source = DataSource::DB->new();
	@clients = @{ $data_source->expand_client_group( \@clients ) };
	my ($today_weekday) = (localtime())[6];
	$today_weekday = normalize_weekday($today_weekday-1); ## convert to our format
	unless (defined $weekday) {
		$weekday = normalize_weekday($today_weekday-1);
	}
	unless (defined weekday_to_string($weekday)) {
		die "[$weekday] weekday is not in [0..6] interval";
	}
	my $offset_shift = $today_weekday - $weekday;
	if ($offset_shift <= 0) {
		$offset_shift += 7;
	}

	$logger->printf(
		"move appointment sending time from [%s] to [%s] (offset %d)",
		weekday_to_string($weekday),
		weekday_to_string($today_weekday),
		$offset_shift,
	);
	if ($allow_today_appointments) {
		$logger->printf("allow send today appointments");

	}
	for my $username (@clients) {
		my $client_data = $data_source->get_client_data_by_db($username);
		move_schedule($logger, $data_source, $client_data, $weekday, $offset_shift, $allow_today_appointments);
	}
	my $fn = '_appointment_schedule_backup.'.DateUtils->get_current_date_filename().'.sql';
	$logger->printf("write settings backup to [%s]", $fn);
	$data_source->save_sql_commands_to_file($fn, qr/^DELETE/);
	$logger->print_category_stat();
	my $work_time = time() - $start_time;
	$logger->printf("done in %d:%02d\n", $work_time / 60, $work_time % 60);
}
else {
	print <<USAGE;
Usage: $0 [..options...] <client_db1> ...
Move appointments sent at weekday to be send today if posible
Options:
	--resend-weekday=0..6 (0 -> Monday, 6 -> Sunday) by default is today-1
	--allow-today-appointments
USAGE
	exit(1);
}

sub move_schedule {
	my ($logger, $data_source, $client_data, $weekday, $offset_shift, $allow_today_appointments) = @_;

	my $week_day_schedule = get_appointment_schedule_sent_at_weekday($client_data, $weekday);
	if (@$week_day_schedule) {
		for my $schedule (@$week_day_schedule) {
			my $new_offset = $schedule->{'send_offset'} + $offset_shift;
			my $allowing_offset = (
				$allow_today_appointments ?
					$new_offset <= 0 :
					$new_offset < 0
			);
			if ($allowing_offset) {
				$logger->printf(
					"client [%s]: change [%s] appointment [%s] offset to [%s]",
					$client_data->get_username(),
					weekday_to_string( $schedule->{'appointment_week_day'} ),
					$schedule->{'send_offset'},
					$new_offset,
				);
				set_new_schedule($logger, $data_source, $client_data, $schedule->{'appointment_week_day'}, $new_offset);
			}
			else {
				$logger->printf(
					"client [%s]: too late to send [%s] appointment [%s] offset",
					$client_data->get_username(),
					weekday_to_string( $schedule->{'appointment_week_day'} ),
					$schedule->{'send_offset'},
				);
				$logger->register_category('too late to change offset');
			}
		}
	}
	else {
		$logger->printf("client [%s]: no appointment found to be sent at [%s]", $client_data->get_username(), weekday_to_string($weekday));
	}
}

sub set_new_schedule {
	my ($logger, $data_source, $client_data, $appointment_week_day, $send_offset) = @_;

	my %current_schedule;
	my $schedule = $client_data->get_email_appointment_schedule();
	for my $day (@$schedule) {
		$current_schedule{ $day->{'appointment_week_day'} }{ $day->{'send_offset'} } = 1;
	}
	if (exists $current_schedule{ $appointment_week_day }{ $send_offset }) {
		$logger->register_category('schedule already exists');
	}
	else {
		$data_source->set_read_only(0);
		my $schedule_id = $client_data->add_email_appointment_schedule($appointment_week_day, $send_offset);
		if (defined $schedule_id) {
			$data_source->set_read_only(1);
			$client_data->delete_email_appointment_schedule($appointment_week_day, $send_offset, $schedule_id);
		}
		$logger->register_category('add new offset');
	}
}

sub get_appointment_schedule_sent_at_weekday {
	my ($client_data, $weekday) = @_;

	my @days;
	my $current_schedule = $client_data->get_email_appointment_schedule();
	for my $schedule (@$current_schedule) {
		my $send_weekday = normalize_weekday( $schedule->{'appointment_week_day'} + $schedule->{'send_offset'} );
		if ($weekday == $send_weekday) {
			push(@days, $schedule);
		}
	}
	return \@days;
}


sub normalize_weekday {
	my ($weekday) = @_;

	while ($weekday < 0) {
		$weekday += 7;
	}
	return $weekday % 7;
}

sub weekday_to_string {
	my ($weekday) = @_;

	my %days = (
		0 => 'Monday',
		1 => 'Tuesday',
		2 => 'Wednesday',
		3 => 'Thursday',
		4 => 'Friday',
		5 => 'Saturday',
		6 => 'Sunday',
	);
	return $days{$weekday};
}