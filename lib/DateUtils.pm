## $Id$
package DateUtils;

use strict;

use DateTime;
use DateTime::Format::MySQL;

sub now {
	my ($class) = @_;

	my $now = DateTime->now();
    $now->set_time_zone('local');
	return bless {
		'date' => $now,
	}, $class;
}

sub clone {
	my ($self) = @_;

	return bless {
		'date' => $self->{'date'}->clone(),
	}, ref $self;
}

sub parse_mysql_date {
	my ($class, $mysql_date) = @_;

	if ($mysql_date =~ m/^\d{4}-\d{2}-\d{2}$/) {
		$mysql_date .= " 00:00:00";
	}
	my $date = DateTime::Format::MySQL->parse_datetime($mysql_date);
    $date->set_time_zone('local');
	return bless {
		'date' => $date,
	}, $class;
}

sub add_seconds {
	my ($self, $seconds) = @_;

	$self->{'date'}->add(
        'seconds' => $seconds,
    );
}

sub add_days {
	my ($self, $days) = @_;

	$self->{'date'}->add(
        'days' => $days,
    );
}

sub as_mysql_datetime {
	my ($self) = @_;

	return DateTime::Format::MySQL->format_datetime($self->{'date'});
}

sub as_mysql_date {
	my ($self) = @_;

	return DateTime::Format::MySQL->format_date($self->{'date'});
}

sub as_voice_utc {
	my ($self) = @_;

	my $utc_now = $self->{'date'}->clone();
	$utc_now->set_time_zone('UTC');

    return $utc_now->ymd().'T'.$utc_now->hms().'.000Z';
}

sub get_last_year_date_mysql {
	my ($class) = @_;

	my @dt = localtime();
	$dt[4]++;
	$dt[5] += 1900;
	return sprintf("%04d-%02d-01 00:00:00", $dt[5]-1, $dt[4]);
}

sub get_current_date_mysql {
	my ($class) = @_;

	my @dt = localtime();
	$dt[4]++;
	$dt[5] += 1900;
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $dt[5], $dt[4], $dt[3], $dt[2], $dt[1], $dt[0]);
}

sub get_current_date_filename {
	my ($class) = @_;

	my @dt = localtime();
	$dt[4]++;
	$dt[5] += 1900;
	return sprintf("%04d-%02d-%02d-%02d-%02d-%02d", $dt[5], $dt[4], $dt[3], $dt[2], $dt[1], $dt[0]);
}


#sub get_current_date_voice_utc {
#
#}

sub date_diff_in_days {
	my ($class, $first_date, $second_date) = @_;

	my $first_date_ref = DateTime::Format::MySQL->parse_datetime($first_date);
	my $second_date_ref = DateTime::Format::MySQL->parse_datetime($second_date);
#	my $diff = $first_date_ref->subtract_datetime_absolute($second_date_ref);
	my $diff = $first_date_ref - $second_date_ref;
	return $diff->in_units('days');
}

1;