#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Spec;

use lib '../lib';

use CSVWriter;
use DataSource::DB;


my @clients = @ARGV;
if (@clients) {
	my $data_access = DataSource::DB->new();
	$data_access->set_read_only(1);
	my $start_time = time();
#    my $result_file = '_si_patients_without_images.csv';
#    printf "writing result to [%s]\n", $result_file;
#    my $output = CSVWriter->new(
#    	$result_file,
#    	[
#    		'client',
#    		'fname',
#    		'lname',
#    		'birthday',
#    		'broken img count',
#    		'pid',
#    	],
#    );

	for my $client_db (@clients) {
		my $client_data = $data_access->get_client_data_by_db($client_db);
		printf "database source: client [%s]\n", $client_db;
		my $data = find_broken_images($client_data);
#		$output->write_data($data);
	}
	my $work_time = time() - $start_time;
	my $fn = "_delete_missing_invisalign_images.sql";
	printf "write delete commands to [$fn]\n";
	$data_access->save_sql_commands_to_file($fn);
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 <client_db> ...\n";
	exit(1);
}

sub find_broken_images {
	my ($client_data) = @_;

	my $counter = 0;
	my $invisaling_patients = $client_data->get_all_invisalign_patients();
	if (@$invisaling_patients) {
		printf "client [%s]: %d patients to process\n", $client_data->get_username(), scalar @$invisaling_patients;
		my $total = @$invisaling_patients;
		my $missing = 0;
#		my %invalid_patients;
		for my $inv_patient (@$invisaling_patients) {
			my $full_filename = File::Spec->join(
		    	$ENV{'SESAME_COMMON'},
		    	'invisalign-cases',
		    	$inv_patient->{'invisalign_client_id'},
		    	$inv_patient->{'case_number'}.'.txt',
		    );

		    $counter++;
		    if (-f $full_filename) {
		        #unless ($counter % 5000) {
		        printf(
		        	"%s: %d/%d: [%s] - OK\n",
		        	$client_data->get_username(),
		        	$counter,
		        	$total,
		        	$full_filename,
		        );
		        #}
		    } else {
		    	$missing++;
		        printf(
		        	"%s: %d/%d: [%s] - not found\n",
		        	$client_data->get_username(),
		        	$counter,
		        	$total,
		        	$full_filename,
		        );
		        $client_data->delete_invisalign_patient($inv_patient->{'case_number'});
		        $client_data->delete_invisalign_processing_patient($inv_patient->{'case_number'});
		        #$invalid_patients{ $r->{'PatId'} } ++;
		    }
		}

		printf(
			"client [%s]: %d of %d images are missing\n",
			$client_data->get_username(),
			$missing,
			scalar @$invisaling_patients,
		);


		my @data;
#	    for my $pid (keys %invalid_patients) {
#	        my $patient = $client_data->get_si_patient_by_id($pid);
#	        push(
#	        	@data,
#	        	{
#		    		'client'   => $client_data->get_username(),
#		    		'fname'    => $patient->{'FName'},
#		    		'lname'    => $patient->{'LName'},
#		    		'birthday' => $patient->{'BDate'},
#		            'pid'      => $pid,
#		            'broken img count' => $invalid_patients{$pid},
#	        	}
#	        );
#	    }
		return \@data;
	}
	else {
		printf "client [%s]: no invisalign patients\n", $client_data->get_username();
		return [];
	}
}

