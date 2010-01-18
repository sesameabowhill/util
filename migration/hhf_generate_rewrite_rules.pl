#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;

{
	my $data_source_5 = DataSource::DB->new_5();
	my $data_source_4 = DataSource::DB->new_4();

	my %hhf_id_map;

	my $all_client_data_5  = $data_source_5->get_client_data_for_all();
	for my $client_data_5 (@$all_client_data_5) {
		my $username = $client_data_5->get_username();
		my $hhf_id = $client_data_5->get_hhf_id();
		if (defined $hhf_id) {
			my $db_name = $data_source_4->get_database_by_username($username);
			if (defined $db_name) {
				printf "database: [%s]\n", $db_name;
				my $client_data_4 = $data_source_4->get_client_data_by_db($db_name);
				my $hhf_user_id = $client_data_4->get_hhf_user_id();
				if (defined $hhf_user_id) {
					my $hhf_id_in_4 = $client_data_4->get_hhf_id();
					if ($hhf_id eq $hhf_id_in_4) {
						$hhf_id_map{$hhf_user_id} = $client_data_5->get_id();
						printf "map: %d => %d\n", $hhf_user_id, $client_data_5->get_id();
					}
					else {
						printf "client [%s]: HHF guid is not the same\n", $db_name;
					}
				}
				else {
					printf "client [%s]: no HHF is sesame4\n", $db_name;
				}
			}
			else {
				printf "SKIP [%s]: not found in sesame4\n", $username;
			}
		}
		else {
			printf "SKIP [%s]: hhf is not found\n", $username;
		}
	}
	if (keys %hhf_id_map) {
		print "-"x80, "\n";
		my $comments = join(
			"\n",
			map {'## '.$_.' => '.$hhf_id_map{$_}}
			sort { $a <=> $b } keys %hhf_id_map
		);
		my $rules = join(
			"\n",
			map {
				'RewriteCond %{QUERY_STRING} &?id='.$_.'\b&?',
				'RewriteRule ^(.*)$  https://members.sesamecommunications.com/hhf/users/hhf_form.cgi?id='.$hhf_id_map{$_}.'   [L]'
			}
			sort { $a <=> $b } keys %hhf_id_map
		);
		print <<TEXT;
RewriteEngine On
RewriteBase /hhf_users

$comments

$rules

TEXT
	}
}