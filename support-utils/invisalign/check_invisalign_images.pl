#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Spec;

use lib '../lib';

use CSVWriter;
use DataSource::DB;
use Script;

Script->simple_client_loop(
	\@ARGV,
	{
		'read_only' => 1,
		'client_data_handler' => \&find_broken_images,
		'save_sql_to_file' => '_delete_missing_invisalign_images.sql',
	}
);

sub find_broken_images {
	my ($logger, $client_data) = @_;

	my $counter = 0;
	my $invisaling_patients = $client_data->get_all_invisalign_patients();
	if (@$invisaling_patients) {
		printf "client [%s]: %d patients to process\n", $client_data->get_username(), scalar @$invisaling_patients;
		my $total = @$invisaling_patients;
		my $missing = 0;
#		my %invalid_patients;
		my @correct_case_numbers;
		for my $inv_patient (@$invisaling_patients) {
			my $full_filename = $client_data->file_path_for_invisalign_comment(
		    	$inv_patient->{'invisalign_client_id'},
		    	$inv_patient->{'case_number'},
		    );

		    $counter++;
		    if (-f $full_filename) {
		        unless ($counter % 100) {
			        printf(
			        	"%s: %d/%d: [%s] - OK\n",
			        	$client_data->get_username(),
			        	$counter,
			        	$total,
			        	$full_filename,
			        );
		        }
		        push(@correct_case_numbers, $inv_patient->{'case_number'});
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
		$client_data->delete_invisalign_processing_patient_not_in_list(\@correct_case_numbers);
		printf(
			"client [%s]: %d of %d images are missing\n",
			$client_data->get_username(),
			$missing,
			scalar @$invisaling_patients,
		);


		return [];
	}
	else {
		printf "client [%s]: no invisalign patients\n", $client_data->get_username();
		return [];
	}
}

