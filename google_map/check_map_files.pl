#!/usr/bin/perl
## $Id: match_invisalign_patients.pl 3167 2010-07-15 21:44:13Z ivan $

use strict;
use warnings;

use lib qw(../lib);

use CandidateManager;
use DataSource::DB;
use Repair::RepairClincheck;

{
	my (@clients) = @ARGV;
	if (@clients) {
	    my $start_time = time();
		my $data_source = DataSource::DB->new();
		$data_source->set_read_only(1);
		@clients = @{ $data_source->expand_client_group( \@clients ) };
	    for my $client_identity (@clients) {
			my $client_data = $data_source->get_client_data_by_db($client_identity);
			printf "database source: client [%s]\n", $client_identity;
	    	check_office_maps($client_data);
	    }
		my $fn = "_remove_missing_maps.sql";
		printf "write remove commands to [$fn]\n";
		$data_source->save_sql_commands_to_file($fn);
		$data_source->print_category_stat();
	    my $work_time = time() - $start_time;
	    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
	}
	else {
	    print "Usage: $0 <database1> [database2...]\n";
	    exit(1);
	}
}


sub check_office_maps {
	my ($client_data) = @_;

	my $offices = $client_data->get_all_offices();
	for my $office (@$offices) {
		my $google_map_file = $client_data->file_path_for_google_map( $office->{'address_id'} );
		if (-e $google_map_file) {
			$client_data->register_category('map is found');
		}
		else {
			printf(
				"MISSING [%s]: map for [%d] address is missing\n",
				$client_data->get_username(),
				$office->{'address_id'},
			);
			$client_data->delete_google_map( $office->{'address_id'} );
			$client_data->register_category('map is missing (deleted)');
		}
	}
}