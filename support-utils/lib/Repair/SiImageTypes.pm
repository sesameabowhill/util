## $Id$
package Repair::SiImageTypes;

use strict;
use warnings;

use base 'Repair::Base';

## Repair::SiImageTypes::repair
sub repair {
	my ($self, $client_data) = @_;

	my %si_image_types = map {lc $_->{'TypeId'} => $_} @{ $client_data->get_all_si_image_types() };
	my $si_images = $client_data->get_all_si_images();
	my $missing_count = 0;
	my %restore_types;
	for my $si_image (@$si_images) {
		if (exists $si_image_types{lc $si_image->{'TypeId'}}) {
			$self->{'logger'}->register_category('image with good type link');
		} else {
			unless (exists $restore_types{lc $si_image->{'TypeId'}}) {
				$client_data->add_si_image_type($si_image->{'TypeId'}, "Unknown ".$si_image->{'TypeId'});
				$restore_types{lc $si_image->{'TypeId'}} = 1;
				$self->{'logger'}->register_category('image type restored');
			}
			$self->{'logger'}->register_category('image missing type link');
			$self->{'logger'}->printf_slow('%s: image type %s is not found', $client_data->get_username(), $si_image->{'TypeId'});
			$missing_count ++;
		}
	}
	if ($missing_count > 0.2 * @$si_images) {
		$self->{'logger'}->printf('%s: %d of %d images are missing type', $client_data->get_username(), $missing_count, scalar @$si_images);
	}
}

1;