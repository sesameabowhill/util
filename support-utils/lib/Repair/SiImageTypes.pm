## $Id$
package Repair::SiImageTypes;

use strict;
use warnings;

use base 'Repair::Base';

## Repair::SiImageTypes::repair
sub repair {
	my ($self, $client_data) = @_;

	my %si_image_types = map {$_->{'TypeId'} => $_} @{ $client_data->get_all_si_image_types() };
	my $si_images = $client_data->get_all_si_images();
	my $missing_count = 0;
	for my $si_image (@$si_images) {
		if (exists $si_image_types{$si_image->{'TypeId'}}) {
			$self->{'logger'}->register_category('image with good type link');
		} else {
			$client_data->delete_si_image($si_image->{'ImageId'});
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