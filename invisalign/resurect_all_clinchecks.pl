#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Spec;

use lib '../lib';

use DataSource::DB;
use CandidateManager;
use Repair::ResurectClincheck;
use Logger;


{
	my $logger = Logger->new();
	my $data_access = DataSource::DB->new();
	$data_access->set_read_only(1);
	my $start_time = time();

	print "start [get_all_clincheck_files]\n";
	my $clincheck_files = $data_access->get_all_clincheck_files();
	print "end [get_all_clincheck_files]\n";
	@$clincheck_files = sort {$a->{'case_number'} <=> $b->{'case_number'}} @$clincheck_files;
	my $fixer = Repair::ResurectClincheck->new($logger);
	for my $clincheck_file (@$clincheck_files) {
		$fixer->repair_case_number($data_access, $clincheck_file);
	}

	my $work_time = time() - $start_time;
	my $fn = "_resurect_all_clinchecks.sql";
	printf "write resurect commands to [$fn]\n";
	$data_access->save_sql_commands_to_file($fn);

	my $shell_fn = "_resurect_all_clinchecks.sh";
	printf "write shell commands to [$shell_fn]\n";
	$fixer->save_commands($shell_fn);
	$logger->print_category_stat();
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;

}

