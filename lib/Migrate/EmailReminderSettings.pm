## $Id$
package Migrate::EmailReminderSettings;

use strict;
use warnings;

sub migrate {
	my ($class, $client_data_5, $client_data_4) = @_;

	my $old_reminder_settings =  $client_data_4->get_email_reminder_settings();
	my $current_reminder_settings =  $client_data_5->get_email_reminder_settings();
	printf(
		"CLIENT [%s]: [%d] old settings, [%d] new settings\n",
		$client_data_5->get_username(),
		scalar @$old_reminder_settings,
		scalar @$current_reminder_settings,
	);

	my %converted_settings;
	for my $settings (@$current_reminder_settings) {
		$converted_settings{ _generate_key($settings) } = 1;
	}

	for my $settings (@$old_reminder_settings) {
		my $unique_key = _generate_key($settings);
		unless (exists $converted_settings{ _generate_key($settings) }) {
			printf("CLIENT [%s]: copy [%s] settings\n", $client_data_5->get_username(), $unique_key);
			$client_data_5->add_new_reminder_setting($settings);
		}
	}
}

sub _generate_key {
	my ($data) = @_;

	if ($data->{'type'} eq 'standard') {
		return $data->{'type'}.'|'.$data->{'subject'};
	}
	else {
		return $data->{'type'};
	}
}


1;