## $Id$
package Report::PatientsByZipCodes;

use strict;
use warnings;


sub get_columns {
	my ($class) = @_;

	return [ 'type', 'username', 'office', 'zip', 'patients' ];
}

sub generate_report {
    my ($class, $client_data) = @_;

    my $patients = $client_data->get_patients();
    my $all_visited_offices = get_all_visited_offices($client_data);

    my %zip_patients;
    for my $patient (@$patients) {
    	if (exists $all_visited_offices->{ $patient->{'PId'} }) {
    		my $visited_office = $all_visited_offices->{ $patient->{'PId'} };
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
    	for my $zip (sort { $a cmp $b } keys %{ $zip_patients{$office_id} }) {
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

sub get_all_visited_offices {
	my ($client_data) = @_;

	my %all_visited;
	my $visited_offices = $client_data->get_visited_offices();
	for my $office (@$visited_offices) {
		push(
			@{ $all_visited{ $office->{'PId'} } },
			$office,
		);
	}
	my %offices;
	while (my ($pid, $offices) = each %all_visited) {
		@$offices = sort { $b->{'Count'} <=> $a->{'Count'} } @$offices;
		$offices{ $pid } = $offices->[0];
	}
	return \%offices;
}


1;