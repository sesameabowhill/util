#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib '../lib';

use CSVWriter;
use DataSource::DB;

$| = 1;
#/home/sites/site2/web/image_systems/jyavari/si/images

my @clients = @ARGV;
if (@clients) {
	my $data_access = DataSource::DB->new();
	my $start_time = time();
    my $result_file = '_si_patients_without_images.csv';
    printf "writing result to [%s]\n", $result_file;
    my $output = CSVWriter->new(
    	$result_file,
    	[
    		'client',
    		'fname',
    		'lname',
    		'birthday',
    		'broken img count',
    		'pid',
    	],
    );

	for my $client_db (@clients) {
		my $client_data = $data_access->get_client_data_by_db($client_db);
		printf "database source: client [%s]\n", $client_db;
		my $data = find_broken_images($client_data);
		$output->write_data($data);
	}
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 <client_db> ...\n";
	exit(1);
}

sub find_broken_images {
	my ($client_data) = @_;

	my $counter = 0;
	my $images = $client_data->get_all_si_images();
	if (@$images) {
		printf "client [%s]: %d images to process\n", $client_data->get_username(), scalar @$images;
		my $total = @$images;
		my $missing = 0;
		my %invalid_patients;
		for my $r (@$images) {
		    my $full_filename = $client_data->file_path_for_si_image($r->{'FileName'});
		    $counter++;
		    if (-f $full_filename) {
		        unless ($counter % 5000) {
		            print "$counter/$total: [$full_filename] - OK\n";
		        }
		    } else {
		    	$missing++;
		        print "$counter/$total: [$full_filename] - not found\n";
		        $invalid_patients{ $r->{'PatId'} } ++;
		    }
		}

		printf "client [%s]: %d of %d images are missing\n", $client_data->get_username(), $missing, scalar @$images;


		my @data;
	    for my $pid (keys %invalid_patients) {
	        my $patient = $client_data->get_si_patient_by_id($pid);
	        push(
	        	@data,
	        	{
		    		'client'   => $client_data->get_username(),
		    		'fname'    => $patient->{'FName'},
		    		'lname'    => $patient->{'LName'},
		    		'birthday' => $patient->{'BDate'},
		            'pid'      => $pid,
		            'broken img count' => $invalid_patients{$pid},
	        	}
	        );
	    }
		return \@data;
	}
	else {
		printf "client [%s]: no si images\n", $client_data->get_username();
		return [];
	}
}

