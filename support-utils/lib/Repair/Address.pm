## $Id$
package Repair::Address;

use strict;
use warnings;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my $visitors = $client_data->get_all_visitors();
	printf("%s: %d visitors\n", $client_data->get_username(), scalar @$visitors);
	for my $visitor (@$visitors) {
		if (defined $visitor->{'address_id'}) {
			my $address = $client_data->get_address_by_id( $visitor->{'address_id'} );
			if (defined $address) {
				$self->{'logger'}->register_category('visitor with address');
			}
			else {
				if (defined $visitor->{'address_id_in_pms'}) {
					my $pms_address = $client_data->get_address_by_id( $visitor->{'address_id_in_pms'} );
					if (defined $pms_address) {
						$self->{'logger'}->register_category('visitor with invalid address (change to PMS)');
						printf(
							"CHANGE [%s]: replace address of visitor #%d with one from PMS %d\n",
							$client_data->get_username(),
							$visitor->{'id'},
							$visitor->{'address_id_in_pms'},
						);
						$client_data->set_visitor_address_id($visitor->{'id'}, $visitor->{'address_id_in_pms'});
					}
					else {
						$self->{'logger'}->register_category('visitor with invalid PMS address');
						printf(
							"INVALID [%s]: address_id_in_pms is invalid for visitor #%d\n",
							$client_data->get_username(),
							$visitor->{'id'},
						);
					}
				}
				else {
					$self->{'logger'}->register_category('visitor without PMS address');
				}
			}
		}
		else {
			$self->{'logger'}->register_category('visitor without address');
		}
	}
}

1;