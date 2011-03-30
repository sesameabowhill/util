## $Id:$
package Repair::Newsletters;

use strict;
use warnings;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my $ppns = $client_data->get_all_newsletters();
	for my $ppn (@$ppns) {
		my $file = $client_data->file_path_for_newsletter( $ppn->{'letter_hash'} );
		if (-e $file) {
			$self->{'logger'}->register_category('newsletter exists');
		}
		else {
			$self->{'logger'}->printf(
				"ERROR [%s]: file [%s] is missing",
				$client_data->get_username(),
				$file,
			);
			$self->{'logger'}->register_category('newsletters file is missing');
		}
	}
}

1;
