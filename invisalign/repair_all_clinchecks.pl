#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Spec;

use lib '../lib';

use DataSource::DB;
use CandidateManager;
use Fix::RepairClincheck;

{
	my $data_access = DataSource::DB->new();
	$data_access->set_read_only(1);
	my $start_time = time();

	my $case_numbers = $data_access->get_all_case_numbers();
	@$case_numbers = map { {'case_number' => $_} } sort {$a <=> $b} @$case_numbers;
	my $do_file_check = 1;
	if (defined $ARGV[0] && $ARGV[0] eq '--skip-file-check') {
		print "skip file check\n";
		$do_file_check = 0;
	}
	my $fixer = Fix::RepairClincheck->new($do_file_check);
	for my $case_number (@$case_numbers) {
		$fixer->repair_case_number($data_access, $case_number);
	}

	my $work_time = time() - $start_time;
	my $fn = "_repair_all_clinchecks.sql";
	printf "write repair commands to [$fn]\n";
	$data_access->save_sql_commands_to_file($fn);
	my $stat = $data_access->get_categories_stat();
	for my $category (sort keys %$stat) {
		printf("%s - %d\n", $category, $stat->{$category});
	}
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;

}
