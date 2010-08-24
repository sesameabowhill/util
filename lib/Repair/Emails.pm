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
			if (Email::Valid->address($email->{'Email'})) {
				$self->{'logger'}->register_category('valid email');
			}
			else {
				if (defined $email->{'pms_id'}) {
					$self->{'logger'}->register_category('invalid email from PMS');
				}
				else {
					$self->{'logger'}->register_category('invalid email from '.$email->{'Source'}.' (delete)');
					$client_data->delete_email($email->{'id'}, $email->{'visitor_id'});
					printf("DELETE [%s]: invalid email [%s] #%d (visitor #%d)\n", $client_data->get_username(), @$email{'Email', 'id', 'visitor_id'});
				}
			}
		}
		else {
			if (defined $email->{'pms_id'}) {
				$self->{'logger'}->register_category('orphan email from PMS');
			}
			else {
				$self->{'logger'}->register_category('orphan email from '.$email->{'Source'}.' (delete)');
				$client_data->delete_email($email->{'id'}, $email->{'visitor_id'});
				printf("DELETE [%s]: orphan email [%s] #%d (visitor #%d)\n", $client_data->get_username(), @$email{'Email', 'id', 'visitor_id'});
			}
		}
	}
}

1;