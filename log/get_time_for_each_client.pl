#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib';

use DateUtils;

my $prev_username = undef;
my $start_date = undef;

print "username;start;end;time\n";
while (<>) {
	if (m{^(\d+/\d+/\d+\s\d+:\d+:\d+)\s+\[([^\]]+)\]\s+<PID=(\d+):DB=([^>]+)>}) {
		my ($date, $severity, $pid, $username) = ($1, $2, $3, $4);
		$date =~ s!/!-!g;
		if ($username eq '[undef]') {
			## skip
		}
		else {
			if (defined $prev_username) {
				if ($prev_username ne $username) {
					printf(
						"%s;%s;%s;%s\n",
						$prev_username,
						$start_date,
						$date,
						DateUtils->date_diff_in_seconds($date, $start_date),
					);
					$prev_username = $username;
					$start_date = $date;
				}
			}
			else {
				$prev_username = $username;
				$start_date = $date;
			}
		}
	}
}