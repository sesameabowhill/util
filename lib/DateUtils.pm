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
		'now' => $now,
	}, $class;
}

sub add_seconds {
	my ($self, $seconds) = @_;

	$self->{'now'}->add(
        'seconds' => $seconds,
    );
}

sub as_mysql_datetime {
	my ($self) = @_;

	return DateTime::Format::MySQL->format_datetime($self->{'now'});
}

sub as_voice_utc {
	my ($self) = @_;

	my $utc_now = $self->{'now'}->clone();
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

sub get_current_date_voice_utc {

}

sub date_diff_in_days {
	my ($class, $first_date, $second_date) = @_;

	my $first_date_ref = DateTime::Format::MySQL->parse_datetime($first_date);
	my $second_date_ref = DateTime::Format::MySQL->parse_datetime($second_date);
#	my $diff = $first_date_ref->subtract_datetime_absolute($second_date_ref);
	my $diff = $first_date_ref - $second_date_ref;
	return $diff->in_units('days');
}

1;