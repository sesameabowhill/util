## $Id: Phones.pm 2096 2010-06-08 18:45:25Z ivan $
package Repair::Emails;

use strict;
use warnings;

use Email::Valid;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my $emails = $client_data->get_all_emails();
	printf("%s: %d emails\n", $client_data->get_username(), scalar @$emails);
	for my $email (@$emails) {
		my $visitor = $client_data->get_visitor_by_id($email->{'visitor_id'});
		if (defined $visitor) {
			if (Email::Valid->address( $email->{'Email'} )) {
				my $space_count = () = ($email->{'Email'} =~ m/\s/g);
				if ($space_count == 1) { ## remove only single space
					if (defined $email->{'pms_id'}) {
						$self->{'logger'}->register_category('invalid email from PMS');
					}
					else {
						$self->{'logger'}->register_category('email with space (remove space)');
						$self->{'logger'}->printf("UPDATE [%s]: email [%s] with space #%d (visitor #%d)", $client_data->get_username(), @$email{'Email', 'id', 'visitor_id'});
						(my $new_email = $email->{'Email'}) =~ s/\s//g;
						$client_data->set_email_address_by_id($email->{'id'}, $new_email);
					}
				}
				elsif ($space_count == 0) {
					$self->{'logger'}->register_category('valid email');
				}
				else {
					$self->_process_invalid_email($client_data, $email);
				}
			}
			else {
				$self->_process_invalid_email($client_data, $email);
			}
		}
		else {
			if (defined $email->{'pms_id'}) {
				$self->{'logger'}->register_category('orphan email from PMS');
			}
			else {
				$self->{'logger'}->register_category('orphan email from '.$email->{'Source'}.' (delete)');
				$self->{'logger'}->printf_slow("DELETE [%s]: orphan email [%s] #%d (visitor #%d)", $client_data->get_username(), @$email{'Email', 'id', 'visitor_id'});
				$client_data->delete_email($email->{'id'}, $email->{'visitor_id'});
			}
		}
	}
}

sub _process_invalid_email {
	my ($self, $client_data, $email) = @_;

	if (defined $email->{'pms_id'}) {
		$self->{'logger'}->register_category('invalid email from PMS');
	}
	else {
		$self->{'logger'}->register_category('invalid email from '.$email->{'Source'}.' (delete)');
		$self->{'logger'}->printf("DELETE [%s]: invalid email [%s] #%d (visitor #%d)", $client_data->get_username(), @$email{'Email', 'id', 'visitor_id'});
		$client_data->delete_email($email->{'id'}, $email->{'visitor_id'});
	}
}

1;