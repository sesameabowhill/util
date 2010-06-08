#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

use Repair::Phones;
use Repair::Address;

{
	my $data_source = DataSource::DB->new();
	$data_source->set_read_only(1);

	my %actions = (
		'phones' => 'Repair::Phones',
		'address' => 'Repair::Address',
	);

	my ($action, @clients) = @ARGV;
	$action ||= '';

	if (exists $actions{$action} && @clients) {
	    my $start_time = time();
	    my $repair = $actions{$action}->new();
		for my $client_db (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_db);
			$repair->repair($client_data);
		}
		my $fn = "_repair_".$action.".sql";
		printf "write repair commands to [$fn]\n";
		$data_source->save_sql_commands_to_file($fn);

		my $stat = $data_source->get_categories_stat();
		for my $category (sort keys %$stat) {
			printf("%s - %d\n", $category, $stat->{$category});
		}

	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
		my @actions = sort keys %actions;
		print "Usage: $0 <".join('|', @actions)."> <client_db1> ...\n";
		exit(1);
	}
}
