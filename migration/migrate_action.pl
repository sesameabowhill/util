#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

use Migrate::EmailReminderSettings;
use Migrate::HHFForms;
use Migrate::HHFAll;
use Migrate::SRMResources;
use Migrate::SIColleagues;
use Migrate::PatientPasswords;
use Migrate::PatientPhones;
{
	my $data_source_5 = DataSource::DB->new_5();
	my $data_source_4 = DataSource::DB->new_4();

	my %actions = (
		'email_settings'    => 'Migrate::EmailReminderSettings',
		'hhf_forms'         => 'Migrate::HHFForms',
		'hhf_all'           => 'Migrate::HHFAll',
		'srm'               => 'Migrate::SRMResources',
		'si_colleagues'     => 'Migrate::SIColleagues',
		'patient_passwords' => 'Migrate::PatientPasswords',
		'patient_phones'    => 'Migrate::PatientPhones',
	);

	my ($action, @clients) = @ARGV;
	$action ||= '';

	if (exists $actions{$action} && @clients) {
	    my $start_time = time();
	    my $migrator = $actions{$action}->new();
		for my $client_db_5 (@clients) {
			my $client_data_5 = $data_source_5->get_client_data_by_db($client_db_5);
			my $username = $client_data_5->get_username();
			my $db_name = $data_source_4->get_database_by_username($username);
			if (defined $db_name) {
				my $client_data_4 = $data_source_4->get_client_data_by_db($db_name);
				$migrator->migrate($client_data_5, $client_data_4);
			}
			else {
				printf "SKIP [%s]: client is not found sesame4\n";
			}
		}
		$data_source_5->print_category_stat();
	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
		my @actions = sort keys %actions;
		print "Usage: $0 <".join('|', @actions)."> <client_db1> ...\n";
		exit(1);
	}
}

