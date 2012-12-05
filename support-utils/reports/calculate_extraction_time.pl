#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw(../lib);

use CSVWriter;
use DataSource::DB;
use DateUtils;
use Logger;

use constant {
	'TYPE' => 1,
	'START' => 2,
	'FINISH' => 3,
	'INITIAL' => 'initial',
	'DIFF' => 'diff',
	'UNKNOWN' => 'unknown',
};

{
	my $logger = Logger->new();
	my $data_source = DataSource::DB->new();
	my $start_time = time();
	my $result_file = '_extraction_time.csv';
	$logger->printf("writing result to [%s]", $result_file);
	my $output = CSVWriter->new(
		$result_file,
		[ 'id', 'client_id', 'start', 'seconds', 'is_initial' ],
	);
	$logger->printf("database [%s]", $data_source->get_connection_info());
	find_uploads($logger, $data_source->{'dbh'}, $output);
	$logger->print_category_stat();
	my $work_time = time() - $start_time;
	$logger->printf("done in %d:%02d", $work_time / 60, $work_time % 60);
}

sub find_uploads {
    my ($logger, $dbh, $output) = @_;
	
	$logger->printf("select");
	my $qr = $dbh->selectall_arrayref("SELECT id, client_id, dt, Description FROM extractor_log", { 'Slice' => {} });
	$logger->printf("sorting");
	$qr = [ sort {$a->{'id'} <=> $b->{'id'}} @$qr];
	my %last;
	for my $row (@$qr) {
		my $type = type_by_description($row->{'Description'});
		if (exists $last{$row->{'client_id'}}) {
			if ($type eq TYPE) {
				$logger->register_category('upload did not finish (type '.$last{$row->{'client_id'}}{'is_initial'}.')');
				$last{$row->{'client_id'}} = {
					'start' => $row->{'dt'},
					'is_initial' => ($row->{'Description'} =~ m{initial} ? INITIAL : DIFF),
					'id' => $row->{'id'},
				};
			} elsif ($type eq START) {
				if ($last{$row->{'client_id'}}{'is_initial'} eq UNKNOWN) {
					$logger->register_category('upload did not finish (type '.$last{$row->{'client_id'}}{'is_initial'}.')');
					$last{$row->{'client_id'}} = {
						'start' => $row->{'dt'},
						'is_initial' => UNKNOWN,
						'id' => $row->{'id'},
					};
				} else {
					## start after type
				}
			} elsif ($type eq FINISH) {
				my $start = delete $last{$row->{'client_id'}};
				$output->write_item(
					{
						'client_id' => $row->{'client_id'},
						'start' => "* ".$start->{'start'},
						'seconds' => DateUtils->date_diff_in_seconds($row->{'dt'}, $start->{'start'}),
						'is_initial' => $start->{'is_initial'},
						'id' => $start->{'id'},
					}
				);
				$logger->printf_slow("session found (type %s)", $start->{'is_initial'});
				$logger->register_category('session found (type '.$start->{'is_initial'}.')');
			} else {
				$logger->register_category("unexpected line");
			}
		} else {
			if ($type eq TYPE) {
				$last{$row->{'client_id'}} = {
					'start' => $row->{'dt'},
					'is_initial' => ($row->{'Description'} =~ m{initial} ? INITIAL : DIFF),
					'id' => $row->{'id'},
				};
			} elsif ($type eq START) {
				$last{$row->{'client_id'}} = {
					'start' => $row->{'dt'},
					'is_initial' => UNKNOWN,
					'id' => $row->{'id'},
				};
				$logger->register_category('upload without type');
			} elsif ($type eq FINISH) {
				$logger->register_category("ignore end without start");
			} else {
				$logger->register_category("unexpected line");
			}
		}
	}
}

sub type_by_description {
    my ($description) = @_;

    if ($description =~ m{Upload type}) {
    	return TYPE;
    } elsif ($description =~ m{Data Extraction Started}) {
    	return START;
    } elsif ($description =~ m{Upload xml to Sesame server started}) {
    	return FINISH;
    }
    return undef;
}