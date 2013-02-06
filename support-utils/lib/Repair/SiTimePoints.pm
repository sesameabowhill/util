## $Id$
package Repair::SiTimePoints;

use strict;
use warnings;

use base 'Repair::Base';

## Repair::SiTimePoints::repair
## b 26 @$si_image
sub repair {
	my ($self, $client_data) = @_;

	my $si_patients = $client_data->get_all_si_patients();
	for my $si_patient (@$si_patients) {
		$self->{'logger'}->printf_slow("images of [%s]", $si_patient->{'PatId'});
		$self->fix_patient($client_data, $si_patient);
	}

}

sub fix_patient {
    my ($self, $client_data, $si_patient) = @_;
	
    my $si_images = $client_data->get_si_images($si_patient->{'PatId'});
    my %time_points = map {$_->{'TimePoint'} => $_} @{ $client_data->get_si_patient_timepoint_link($si_patient->{'PatId'}) };
    my %image_time_points = map {$_->{'TimePoint'} => 1} @$si_images;
    my %numeric_image_time_points = map {$_ => 1} grep {/^[1-9]\d*|0$/} keys %image_time_points;

    my @missing_time_points = grep {! exists $time_points{$_} } keys %image_time_points;
    if (@missing_time_points) {
    	if (keys %time_points) {
	    	if (keys %numeric_image_time_points == keys %image_time_points) {
	    		my $time_point_remap = $self->get_time_point_remap([ values %time_points ]);
	    		my @missing_numeric = grep {! exists $time_point_remap->{$_}} map {$_->{'TimePoint'}} @$si_images;
	    		if (@missing_numeric) {
					$self->{'logger'}->printf("%s: missing time points didn't match to numeric", $si_patient->{'PatId'});
					$self->{'logger'}->register_category("patient with missing time point, but can't match to numeric");
				} else {
				    for my $si_image (@$si_images) {
				    	$client_data->update_si_image_time_point(
				    		$si_image->{'ImageId'}, 
				    		$time_point_remap->{$si_image->{'TimePoint'}}, 
				    		"TimePoint [".$si_image->{'TimePoint'}."] PatId [".$si_image->{'PatId'}."]"
			    		);
						$self->{'logger'}->register_category("fix images with missing time point");
				    }
					$self->{'logger'}->register_category("fix patients with missing time point");
				}
			} else {
				$self->{'logger'}->printf("%s: missing time points are not numeric", $si_patient->{'PatId'});
				$self->{'logger'}->register_category("patient with missing time point, but not numeric");
			}
		} else {
			$self->{'logger'}->printf_slow("%s: no time points found for patient (image time points %d)", $si_patient->{'PatId'}, scalar keys %image_time_points);
			$self->{'logger'}->register_category("fix missing time points for patient");
			for my $time_point (keys %image_time_points) {
				$client_data->insert_si_patient_timepoint_link($si_patient->{'PatId'}, $time_point, 'Unknown-'.$time_point, "PatId [".$si_patient->{'PatId'}."]");
				$self->{'logger'}->register_category("new time point link");
			}
		}
	} else {
		$self->{'logger'}->register_category("patient with all time points");
	}

}

sub get_time_point_remap {
    my ($self, $time_points) = @_;

    my $count = 0;
    my %remap;
	for my $time_point (sort {$a->{'TimePoint'} cmp $b->{'TimePoint'}} @$time_points) {
		$remap{$count ++} = $time_point->{'TimePoint'};
	}
	return \%remap;
}

1;

