#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw(../lib);

use CSVWriter;
use CandidateManager;
use DataSource::DB;
use Logger;

use Report::CancelledMembers;
use Report::FinancialReminders;
use Report::MarketResearch;
use Report::PatientsByZipCodes;

{
	my %reports = (
		'cancelled_members'     => 'Report::CancelledMembers',
		'financial_reminders'   => 'Report::FinancialReminders',
		'market_research'       => 'Report::MarketResearch',
		'online_payments'       => 'Report::OnlinePaymentStat',
		'patients_by_zip_codes' => 'Report::PatientsByZipCodes',
	);
	my ($report_type, @clients) = @ARGV;
	my $logger = Logger->new();
	if (@clients) {
		if (exists $reports{$report_type}) {
			my $report_class = $reports{$report_type};
			my $data_source = DataSource::DB->new();
			my $start_time = time();
			my $result_file = '_'.$report_type.'.csv';
			$logger->printf("writing result to [%s]", $result_file);
			my $output = CSVWriter->new(
				$result_file,
				$report_class->get_columns(),
			);
			if ($data_source->can('expand_client_group')) {
				@clients = @{ $data_source->expand_client_group( \@clients ) };
			}
			for my $client_identity (@clients) {
				my $client_data = $data_source->get_client_data_by_db($client_identity);
				$logger->printf("database source: client [%s]", $client_identity);
				my $data = $report_class->generate_report($client_data, $logger);
				$output->write_data($data);
			}
			$logger->print_category_stat();
			my $work_time = time() - $start_time;
			$logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
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

