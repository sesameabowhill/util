#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw(../lib);

use CandidateManager;
use CSVWriter;
use DataSource::DB;

use Report::PatientsByZipCodes;
use Report::FinancialReminders;
use Report::CancelledMembers;
use Report::MarketResearch;

{
	my %reports = (
		'patients_by_zip_codes' => 'Report::PatientsByZipCodes',
		'financial_reminders'   => 'Report::FinancialReminders',
		'cancelled_members'     => 'Report::CancelledMembers',
		'market_research'       => 'Report::MarketResearch',
	);
	my ($report_type, @clients) = @ARGV;
	if (@clients) {
		if (exists $reports{$report_type}) {
			my $report_class = $reports{$report_type};
			my $data_source = DataSource::DB->new();
		    my $start_time = time();
		    my $result_file = '_'.$report_type.'.csv';
		    printf "writing result to [%s]\n", $result_file;
		    my $output = CSVWriter->new(
		    	$result_file,
		    	$report_class->get_columns(),
		    );
		    for my $client_identity (@clients) {
				my $client_data = $data_source->get_client_data_by_db($client_identity);
				printf "database source: client [%s]\n", $client_identity;
		    	my $data = $report_class->generate_report($client_data);
		    	$output->write_data($data);
		    }
		    my $work_time = time() - $start_time;
		    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
		}
		else {
			die "unknown report type [$report_type]";
		}
	}
	else {
		my @reports = sort keys %reports;
	    print "Usage: $0 <".join('|', @reports)."> <database1> [database2...]\n";
	    exit(1);
	}
}

