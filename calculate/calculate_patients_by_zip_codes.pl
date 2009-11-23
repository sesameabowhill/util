#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw(../lib);

use DataSource::DB;
use CSVWriter;


my @clients = @ARGV;
if (@clients) {
	my $data_source = DataSource::DB->new();
    my $start_time = time();
    my $result_file = 'result.csv';
    printf "writing result to [%s]\n", $result_file;
    my $output = CSVWriter->new(
    	$result_file, 
    	[ 'type', 'username', 'office', 'zip', 'patients' ],
    );
    for my $client_identity (@clients) {
		my $client_data = $data_source->get_client_data_by_db($client_identity);
		printf "database source: client [%s]\n", $client_identity;
    	my $data = get_patients_by_zip_data($client_data);
    	$output->write_data($data);
    }
    my $work_time = time() - $start_time;
    printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
} 
else {
    print "Usage: $0 <database1> [database2...]\n";
    exit(1);
}
    	
    	
sub get_patients_by_zip_data {
    my ($client_data) = @_;
    
    my $patients = $client_data->get_patients();
    my %zip_patients;
    for my $patient (@$patients) {
    	my $visited_offices = $client_data->get_visited_offices_by_pid( $patient->{'PId'} );
    	if (@$visited_offices) {
	    	@$visited_offices = sort { $b->{'Count'} <=> $a->{'Count'} } @$visited_offices;
    		my $visited_office = $visited_offices->[0];
	    	my $addresses = $client_data->get_addresses_by_pid( $patient->{'PId'} );
	    	for my $address (@$addresses) {
	    		$zip_patients{ $visited_office->{'OfficeId'} }{ $address->{'Zip'} }{ $patient->{'PId'} } = $patient;
	    	}
    	}
    	else {
    		## skip patient without appointments
    	}
    }
    my %office = map { $_->{'OfficeId'} => $_ } @{ $client_data->get_offices() };
    my @data;
    for my $office_id (keys %zip_patients) {
    	for my $zip (sort { $a <=> $b } keys %{ $zip_patients{$office_id} }) {
    		my $patients_count = $zip_patients{$office_id}{$zip};
    		push(
    			@data,
    			{
    				'type'     => $client_data->get_full_type(), 
    				'username' => $client_data->get_db_name(), 
    				'office'   => ( $office{$office_id}{'OfficeLocation'} || $office{$office_id}{'OfficeName'} ), 
    				'zip'      => $zip, 
    				'patients' => scalar keys %$patients_count, 
    			}
    		); 
    	}
    }
    return \@data;
}