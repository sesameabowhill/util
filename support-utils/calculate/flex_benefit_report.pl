#!/usr/bin/perl
## $Id$
use strict;
use warnings;


use DBI;
use Date::Manip;

use constant DB_SERVER			=> $ENV{SESAME_DB_SERVER};
use constant DB_USER			=> 'admin';
use constant DB_PASSWD			=> 'higer4';


my $database = $ARGV[0];
unless ($database) {
	print <<USAGE;
use: $0 <username>
    or $0 all_doctors
USAGE
	exit(1);
}



my $dbi = DBI->connect("DBI:mysql:dentists:" . DB_SERVER, DB_USER, DB_PASSWD,
                           {
                            RaiseError => 1,
                            ShowErrorStatement => 1,
                 		   });

my $cond = ( $database eq 'all_doctors' ? '' : ' AND cl.cl_mysql='.$dbi->quote($database) );

my @arr_doctors = @{ $dbi->selectall_arrayref(<<SQL, { Slice => {} })};
SELECT distinct cl.cl_status, cl.cl_mysql
FROM email_messaging.reminder_settings s
LEFT JOIN dentists.clients cl ON (cl.cl_id=substring(s.client_id,2))
WHERE
	s.is_enabled=1 AND s.type in ('benefit', 'flex') AND s.client_id like 'd%'
	AND cl.cl_status=1$cond
SQL

my %type_name = (
	'3' => 'flex',
	'2' => 'benefits',
);

print "client;client status;reminder type;was sent;end date;reminder date;patient\n";
foreach my $cl (@arr_doctors)
{
	my $db_name = $cl->{cl_mysql};
    next if !$db_name;

    my $dbh = DBI->connect("DBI:mysql:" . $db_name . ":" . DB_SERVER, DB_USER, DB_PASSWD,
                       {
                        RaiseError => 1,
                        ShowErrorStatement => 1,
                       });

    #print "$db_name\n";

    my $dates = $dbh->selectall_arrayref(<<SQL, { Slice => {} });
SELECT pl.end_date, pl.type, p.fname, p.lname
FROM ins_pat_plans pl LEFT JOIN Patients p on pl.pid=p.PId
WHERE p.PId is not null AND pl.end_date is not null AND pl.type IN (2,3) AND pl.is_deleted=0
SQL
	my $now_dt = ParseDate('today');
	foreach my $d (@$dates){
		my $type = $type_name{ $d->{type} };
		my $end_date = $d->{end_date};
		my $monthes_before = $dbh->selectrow_array(<<SQL, undef, $type);
SELECT IVal FROM profile
WHERE PKey=CONCAT('Reminder.', ?, '->Schedule')
SQL
		my ($month, $day, $year) = $end_date =~ /(\d\d)(\d\d)(\d{4})/;
		my $end_dt = "$year-$month-$day";
		my $reminder_dt = DateCalc(ParseDate("$year-$month-$day"), "- $monthes_before months");

		if (defined $reminder_dt) {
			print(
				$db_name, ";",
				$cl->{cl_status}, ";",
				$type, ";",
				($reminder_dt lt $now_dt ? 1 : 0), ";",
				$end_dt, ";",
				UnixDate($reminder_dt, '%Y-%m-%d'), ";",
				$d->{lname}.", ".$d->{fname}, "\n",
			);
		} else {
			warn "$db_name: looks like invalid end_date [$end_date]";
		}
	}

}

print "done\n";
