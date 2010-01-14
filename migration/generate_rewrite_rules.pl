#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

{
	my $data_source_5 = DataSource::DB->new_5();
	my $data_source_4 = DataSource::DB->new_4();

	my $all_client_data_5  = $data_source_5->get_client_data_for_all();
	for my $client_data_5 (@$all_client_data_5) {
		my $db_name = $client_data_5->get_db_name();
		if ($data_source_4->is_client_exists($db_name)) {
			my $clien_data_4 = $data_source_4->get_client_data_by_db($db_name);
			printf "db: [%s]\n", $db_name;
		}
		else {
			printf "SKIP [%s]: not found in sesame4\n", $db_name;
		}
	}
}