#!/usr/bin/perl
## $Header$

use strict;
use warnings;
use feature ':5.10';

use File::Spec;
use Log::Log4perl;
use String::CityHash 'cityhash64';

use lib qw( ../lib );

use Logger;

my ($id, $client_id, $pms_id) = @ARGV;

if (defined $pms_id) {
	my @pms_ids = length $pms_id ? ($pms_id) : (0..100_000);
	my @client_ids = length $client_id ? ($client_id) : (1..5000);
	my $logger = Logger->new();
	LOOP:
	my $matched = 0;
	for my $table ('', 'patient', 'responsible') {
		for my $pms_id (@pms_ids) {
			for my $client_id (@client_ids) {
				if (defined find_by_table($logger, $id, $client_id, $pms_id, $table)) {
					$matched = 1;
					last LOOP;
				}
			}
		}
	}
	unless ($matched) {
		$logger->printf("didn't find any match");
	}
}
else {
    print <<USAGE;
Usage: $0 <id> [client_id] [pms_id]
    id - to find CityHash for
USAGE
    exit(1);
}


sub find_by_table {
	my ($logger, $id, $client_id, $pms_id, $table) = @_;

	$logger->printf_slow("trying id [%s] client id [%s] pms id [%s] table [%s]", $id, $client_id, $pms_id, $table);
	my $original = $client_id.":".$pms_id.($table ? ":".$table : "");
	my $test_id = cityhash64($original);
	if ($test_id eq $id) {
		$logger->printf("matched client id [%s] pms id [%s] table [%s]", $client_id, $pms_id, $table);
		return $test_id;
	}
	return undef;
}

