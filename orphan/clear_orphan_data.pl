#!/usr/bin/perl
## $Id: repair_data.pl 3167 2010-07-15 21:44:13Z ivan $

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

use Orphan::SentMailLog;
use Orphan::EmailContactLog;

{
	$|=1;
	my %actions = (
		'sent_mail_log'     => 'Orphan::SentMailLog',
		'email_contact_log' => 'Orphan::EmailContactLog',
	);

	my ($action) = @ARGV;
	$action ||= '';

	if (exists $actions{$action}) {
		my $data_source = DataSource::DB->new();
		$data_source->set_read_only(1);

	    my $start_time = time();
	    my $repair = $actions{$action}->new();
		$repair->clear_orphan_data($data_source);
		my $fn = "_clear_orphan_".$action.".sql";
		printf "write repair commands to [$fn]\n";
		$data_source->save_sql_commands_to_file($fn);

		$data_source->print_category_stat();

	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
		my @actions = sort keys %actions;
		print "Usage: $0 <".join('|', @actions).">\n";
		exit(1);
	}
}