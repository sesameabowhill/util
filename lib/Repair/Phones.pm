## $Id$
package Repair::Phones;

use strict;
use warnings;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my $phones = $client_data->get_all_phones();
	printf("%s: %d phones\n", $client_data->get_username(), scalar @$phones);
	for my $phone (@$phones) {
		my $visitor = $client_data->get_visitor_by_id($phone->{'visitor_id'});
		if (defined $visitor) {
			if (length( $phone->{'number'} ) < 11) {
				if (defined $phone->{'pms_id'}) {
					if ($phone->{'sms_active'} || $phone->{'voice_active'}) {
						$client_data->register_category('invalid active phone from PMS');
						printf("DEACTIVATE [%s]: active PMS phone [%s] #%d (visitor #%d)\n", $client_data->get_username(), @$phone{'number', 'id', 'visitor_id'});
					}
					else {
						$client_data->register_category('invalid phone from PMS');
					}
				}
				else {
					$client_data->register_category('invalid phone from '.$phone->{'source'}.' (delete)');
					$client_data->delete_phone($phone->{'id'}, $phone->{'visitor_id'});
					printf("DELETE [%s]: invalid phone [%s] #%d (visitor #%d)\n", $client_data->get_username(), @$phone{'number', 'id', 'visitor_id'});
				}
			}
			else {
				$client_data->register_category('valid phone');
			}
		}
		else {
			if (defined $phone->{'pms_id'}) {
				$client_data->register_category('orphan phone from PMS');
			}
			else {
				$client_data->register_category('orphan phone from '.$phone->{'source'}.' (delete)');
				$client_data->delete_phone($phone->{'id'}, $phone->{'visitor_id'});
				printf("DELETE [%s]: orphan phone [%s] #%d (visitor #%d)\n", $client_data->get_username(), @$phone{'number', 'id', 'visitor_id'});
			}
		}
	}
}

1;