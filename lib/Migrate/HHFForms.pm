## $Id$
package Migrate::HHFForms;

use strict;
use warnings;

sub migrate {
	my ($class, $client_data_5, $client_data_4) = @_;

	if ($client_data_5->get_hhf_id() eq $client_data_4->get_hhf_id()) {
		my $hhf_id = $client_data_5->get_hhf_id();
		printf "CLIENT [%s]: hhf id [%s]\n", $client_data_5->get_username(), $hhf_id;
		my $forms_4 = $client_data_4->get_all_hhf_forms();
		my %forms_5 = (
			map {_generate_key($_) => $_}
			@{ $client_data_5->get_all_hhf_forms() }
		);
		for my $form (@$forms_4) {
			my $form_key_4 = _generate_key($form);
			unless (exists $forms_5{$form_key_4}) {
				printf "copy form [%s]\n", $form_key_4;
				$client_data_5->add_hhf_form(
					$form->{'filldate'},
					$form->{'fname'},
					$form->{'lname'},
					$form->{'birthdate'},
					$form->{'note'},
					$form->{'signature'},
					$form->{'body'},
				);
			}
		}
	}
	else {
		printf "ERROR [%s]: hhf has different guid\n", $client_data_5->get_username();
	}
}



sub _generate_key {
	my ($data) = @_;

	return join('|', @$data{'filldate', 'fname', 'lname'});
}


1;