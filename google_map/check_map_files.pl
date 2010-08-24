#!/usr/bin/perl
## $Id: match_invisalign_patients.pl 3167 2010-07-15 21:44:13Z ivan $

use strict;
use warnings;

use lib qw(../lib);

use Script;

Script->simple_client_loop(
	\@ARGV,
	{
		'read_only' => 1,
		'client_data_handler' => \&check_office_maps,
		'save_sql_to_file' => '_remove_missing_maps.sql',
	}
);


sub check_office_maps {
	my ($logger, $client_data) = @_;

	my $offices = $client_data->get_all_offices();
	for my $office (@$offices) {
		my $google_map_file = $client_data->file_path_for_google_map( $office->{'address_id'} );
		if (-e $google_map_file) {
			$logger->register_category('map is found');
		}
		else {
			printf(
				"MISSING [%s]: map for [%d] address is missing\n",
				$client_data->get_username(),
				$office->{'address_id'},
			);
			$client_data->delete_google_map( $office->{'address_id'} );
			$logger->register_category('map is missing (deleted)');
		}
	}
}