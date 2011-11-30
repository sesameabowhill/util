#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

if (@ARGV > 1) {
	my $remap_table = shift @ARGV;
	my $data_source = DataSource::DB->new();
	print "remap for [$remap_table]\n";
	for my $client_db (@ARGV) {
		print "processing [$client_db]\n";
		my $client_data = $data_source->get_client_data_by_db($client_db);
		my %remap_tables = map {$_->{'name'} => $_->{'id'}} @{ $client_data->get_all_remap_tables() };
		if (exists $remap_tables{$remap_table}) {
			my $table_id = $remap_tables{$remap_table};
			my $ids = $client_data->get_all_ids_by_table_name($remap_table);
			for my $id (@$ids) {
				my $current_remap_id = $client_data->get_reverse_remap($table_id, $id);
				if (defined $current_remap_id) {
					print "id [$id] is already mapped to [$current_remap_id]\n";
				}
				else {
					print "add remap for [$id]\n";
					$client_data->add_remap($table_id, $id, $id);
				}
			}
		}
		else {
			die "remap table [$remap_table] is not available for [$client_db]";
		}
	}
}
else {
	print "Usage: $0 <table_name> <client_db_name> ...\n";
	exit(1);
}