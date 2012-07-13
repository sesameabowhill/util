#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use Getopt::Long;

use lib '../lib';

use DataSource::DB;
use DateUtils;
use Logger;

my ($old_weekday, $new_weekday, $allow_today_appointments);
GetOptions(
	'old-send-weekday=i' => \$old_weekday,
	'new-send-weekday=i' => \$new_weekday,
	'allow-today-appointments!'  => \$allow_today_appointments,
);

my (@clients) = @ARGV;
if (@clients) {
	$|=1;
	my $logger = Logger->new();
	my $start_time = time();
	my $data_source = DataSource::DB->new();
	@clients = @{ $data_source->expand_client_group( \@clients ) };
	my $today_weekday = $new_weekday; 
	unless (defined $today_weekday) {
		($today_weekday) = (localtime())[6];
		$today_weekday = normalize_weekday($today_weekday-1); ## convert to our format
	}
	unless (defined $old_weekday) {
		$old_weekday = normalize_weekday($today_weekday-1);
	}
	unless (defined weekday_to_string($today_weekday)) {
		die "[$new_weekday] new weekday is not in [0..6] interval";
	}
	unless (defined weekday_to_string($old_weekday)) {
		die "[$old_weekday] old weekday is not in [0..6] interval";
	}
	my $offset_shift = $today_weekday - $old_weekday;
	if ($offset_shift <= 0) {
		$offset_shift += 7;
	}

	$logger->printf(
		"move appointment sending time from [%s] to [%s] (offset %d)",
		weekday_to_string($old_weekday),
		weekday_to_string($today_weekday),
		$offset_shift,
	);
	if ($allow_today_appointments) {
		$logger->printf("allow send today appointments");

	}
	for my $username (@clients) {
		my $client_data = $data_source->get_client_data_by_db($username);
		for my $reminder_type ('email','voice','sms') {
			move_schedule($logger, $data_source, $client_data, $reminder_type, $old_weekday, $offset_shift, $allow_today_appointments);
		}
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
Move appointments sent date to new weekday if possible
Options:
	--new-send-weekday=0..6 - by default is today
	--old-send-weekday=0..6 - by default is today - 1
	--allow-today-appointments - allow appointents for new date to be sent on same day
Days of the week:
	0 - Monday
	1 - Tuesday
	2 - Wednesday
	3 - Thursday
	4 - Friday
	5 - Saturday
	6 - Sunday
USAGE
	exit(1);
}

sub move_schedule {
	my ($logger, $data_source, $client_data, $reminder_type, $weekday, $offset_shift, $allow_today_appointments) = @_;

	my $week_day_schedule = get_appointment_schedule_sent_at_weekday($client_data, $reminder_type, $weekday);
	if (@$week_day_schedule) {
		for my $schedule (@$week_day_schedule) {
			my $new_offset = $schedule->{'send_offset'} - $offset_shift;
			my $allowing_offset = (
				$allow_today_appointments ?
					$new_offset >= 0 :
					$new_offset > 0
			);
			if ($allowing_offset) {
				$logger->printf(
					"client [%s] - [%s]: change [%s] appointment [%s] offset to [%s]",
					$client_data->get_username(),
					$reminder_type,
					$schedule->{'appointment_week_day'},
					$schedule->{'send_offset'},
					$new_offset,
				);
				set_new_schedule($logger, $data_source, $client_data, $reminder_type, $schedule, $new_offset);
			}
			else {
				$logger->printf(
					"client [%s] - [%s]: too late to send [%s] appointment [%s] offset",
					$client_data->get_username(),
					$reminder_type,
					$schedule->{'appointment_week_day'},
					$schedule->{'send_offset'},
				);
				$logger->register_category('too late to change offset');
			}
		}
	}
	else {
		$logger->printf("client [%s] - [%s]: no appointment found to be sent at [%s]", $client_data->get_username(), $reminder_type, weekday_to_string($weekday));
	}
}

sub set_new_schedule {
	my ($logger, $data_source, $client_data, $reminder_type, $new_schedule, $send_offset) = @_;

	my %current_schedule;
	my $schedule = $client_data->get_appointment_schedule_by_reminder_type($reminder_type);
	for my $day (@$schedule) {
		$current_schedule{ $day->{'appointment_week_day'} }{ $day->{'send_offset'} . $day->{'send_offset_unit'} } = 1;
	}
	if (exists $current_schedule{ $new_schedule->{'appointment_week_day'} }{ $send_offset . $new_schedule->{'send_offset_unit'} }) {
		$logger->register_category('schedule already exists');
	}
	else {
		$data_source->set_read_only(0);
		my $schedule_id = $client_data->add_appointment_schedule(
			$reminder_type, 
			$new_schedule->{'appointment_week_day'}, 
			$send_offset, 
			$new_schedule->{'send_offset_unit'},
			$new_schedule->{'send_time'},
		);
		if (defined $schedule_id) {
			$data_source->set_read_only(1);
			$client_data->delete_appointment_schedule($reminder_type, $new_schedule->{'appointment_week_day'}, $send_offset, $schedule_id);
		}
		$logger->register_category('add new offset');
	}
}

sub get_appointment_schedule_sent_at_weekday {
	my ($client_data, $reminder_type, $weekday) = @_;

	my @days;
	my $current_schedule = $client_data->get_appointment_schedule_by_reminder_type($reminder_type);
	for my $schedule (@$current_schedule) {
		if ($schedule->{'send_offset_unit'} eq 'week') {
			$schedule->{'send_offset_unit'} = 'day';
			$schedule->{'send_offset'} *= 7;
		}
		if ($schedule->{'send_offset_unit'} eq 'month') {
			$schedule->{'send_offset_unit'} = 'day';
			$schedule->{'send_offset'} *= 30;
		}
		if ($schedule->{'send_offset_unit'} eq 'hour') {
			## skip hour schedule
		} elsif ($schedule->{'send_offset_unit'} eq 'day') {
			my $send_weekday = normalize_weekday( string_to_weekday($schedule->{'appointment_week_day'}) - $schedule->{'send_offset'} );
			if ($weekday == $send_weekday) {
				push(@days, $schedule);
			}
		} else {
			die "unsupported offset unit [" . $schedule->{'send_offset_unit'} . "]";
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

sub string_to_weekday {
	my ($string) = @_;

	my %days = (
		'monday' => 0,
		'tuesday' => 1,
		'wednesday' => 2,
		'thursday' => 3,
		'friday' => 4,
		'saturday' => 5,
		'sunday' => 6,
	);
	return $days{$string};
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