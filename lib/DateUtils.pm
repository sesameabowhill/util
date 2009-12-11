## $Id$
package DateUtils;

use strict;

use DateTime;
use DateTime::Format::MySQL;

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

sub date_diff_in_days {
	my ($class, $first_date, $second_date) = @_;

	my $first_date_ref = DateTime::Format::MySQL->parse_datetime($first_date);
	my $second_date_ref = DateTime::Format::MySQL->parse_datetime($second_date);
#	my $diff = $first_date_ref->subtract_datetime_absolute($second_date_ref);
	my $diff = $first_date_ref - $second_date_ref;
	return $diff->in_units('days');
}

1;