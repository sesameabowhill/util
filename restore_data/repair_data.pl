#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

use Repair::Address;
use Repair::Banners;
use Repair::Emails;
use Repair::Phones;
use Repair::HolidaySettings;
use Logger;

{
	$|=1;
	my $logger = Logger->new();
	my %actions = (
		'phones'  => 'Repair::Phones',
		'address' => 'Repair::Address',
		'emails'  => 'Repair::Emails',
		'holiday_settings' => 'Repair::HolidaySettings',
		'banners' => 'Repair::Banners',
		'newsletters' => 'Repair::Newsletters',
	);

	my ($action, @clients) = @ARGV;
	$action ||= '';

	if (exists $actions{$action} && @clients) {
		my $data_source = DataSource::DB->new();
		$data_source->set_read_only(1);
		@clients = @{ $data_source->expand_client_group( \@clients ) };

	    my $start_time = time();
	    my $repair = $actions{$action}->new($logger);
		for my $client_db (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_db);
			$logger->printf("process [%s]", $client_data->get_username());
			$repair->repair($client_data);
		}
		if (defined $repair->get_commands_extension()) {
			my $fn = "_repair_".$action.$repair->get_commands_extension();
			$logger->printf("write custom commands to [$fn]");
			$logger->save_commands_to_file($fn);
		}
		else {
			my $fn = "_repair_".$action.".sql";
			$logger->printf("write repair commands to [$fn]");
			$data_source->save_sql_commands_to_file($fn);
		}

		$logger->print_category_stat();

	    my $work_time = time() - $start_time;
	    $logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
	}
	else {
		my @actions = sort keys %actions;
		print "Usage: $0 <".join('|', @actions)."> <client_db1> ...\n";
		exit(1);
	}
}
