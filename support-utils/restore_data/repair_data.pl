#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;
use DateUtils;
use Logger;
use Repair::Address;
use Repair::Appointments;
use Repair::Banners;
use Repair::Emails;
use Repair::HolidaySettings;
use Repair::InvisalignClientLinks;
use Repair::NewsletterArticleStat;
use Repair::Newsletters;
use Repair::OrphanClinchecks;
use Repair::Phones;
use Repair::SiImageTypes;
use Repair::VoiceReminderSettings;

{
	$|=1;
	my $logger = Logger->new();
	my %actions = (
		'address' => 'Repair::Address',
		'appointments' => 'Repair::Appointments',
		'banners' => 'Repair::Banners',
		'emails'  => 'Repair::Emails',
		'holiday_settings' => 'Repair::HolidaySettings',
		'invisalign_client_links' => 'Repair::InvisalignClientLinks',
		'newsletters' => 'Repair::Newsletters',
		'orphan_clinchecks' => 'Repair::OrphanClinchecks',
		'phones'  => 'Repair::Phones',
		'ppn_article_stat' => 'Repair::NewsletterArticleStat',
		'si_image_types' => 'Repair::SiImageTypes',
		'voice_reminder_settings' => 'Repair::VoiceReminderSettings',
	);

	my ($action, @clients) = @ARGV;
	$action ||= '';

	if (exists $actions{$action} && @clients) {
		my $data_source = DataSource::DB->new();
		$data_source->set_read_only(1);
		$logger->printf("data from [%s]", $data_source->get_connection_info());
		@clients = @{ $data_source->expand_client_group( \@clients ) };

	    my $start_time = time();
	    my $repair = $actions{$action}->new($logger);
		for my $client_db (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_db);
			$logger->printf_slow("process [%s]", $client_data->get_username());
			$repair->repair($client_data);
		}
		if (defined $repair->get_commands_extension()) {
			my $fn = "_repair_".$action.$repair->get_commands_extension();
			$logger->printf("write custom commands to [$fn]");
			$logger->save_commands_to_file($fn, undef, "created at ".DateUtils->get_current_date_mysql()."\nclients: ".join(', ', @clients));
		}
		else {
			my $fn = "_repair_".$action.".sql";
			$logger->printf("write repair commands to [$fn]");
			$data_source->save_sql_commands_to_file($fn, undef, "created at ".DateUtils->get_current_date_mysql()."\nclients: ".join(', ', @clients));
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
