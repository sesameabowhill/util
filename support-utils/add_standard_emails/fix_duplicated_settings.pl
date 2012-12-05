#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib';

use Script;

Script->simple_client_loop(
	\@ARGV,
	{
		'read_only' => 1,
		'client_data_handler' => \&fix_duplicate_settings,
		'save_sql_to_file' => '_delete_email_reminder_settings.%s.sql',
	}
);


sub fix_duplicate_settings {
    my ($logger, $client_data) = @_;

	my %unique;	
    for my $setting (sort {$a->{'id'} <=> $b->{'id'}} @{ $client_data->get_email_reminder_settings() }) {
    	if ($setting->{'type'} ne 'appointment' && $setting->{'type'} ne 'standard') {
	    	if (exists $unique{$setting->{'type'}}) {
				$unique{$setting->{'type'}} ++;
	    		$logger->register_category($unique{$setting->{'type'}}." instances of ".$setting->{'type'});
	    		$client_data->delete_email_reminder_setting_body($setting->{'id'}, $unique{$setting->{'type'}}." instances of ".$setting->{'type'});
	    	} else {
	    		$unique{$setting->{'type'}} = 1;
	    		$logger->register_category("single ".$setting->{'type'});
	    	}
    	} else {
    		$logger->register_category("skip ".$setting->{'type'});
    	}
	}
}

