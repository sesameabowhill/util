## $Id$
package Repair::VoiceReminderSettings;

use strict;
use warnings;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my $settings = $client_data->get_voice_reminder_settings();

	my %non_appointment_settings;
	for my $setting (@$settings) {
		if ($setting->{'reminder_type'} eq 'appointment') {
			$self->{'logger'}->register_category('appointment setting');
		} else {
			push(@{ $non_appointment_settings{$setting->{'reminder_type'}} }, $setting);
		}
	}

	for my $duplicated_setting_type (grep { @{ $non_appointment_settings{$_} } > 1} keys %non_appointment_settings) {
		my @remove_settings = @{$non_appointment_settings{$duplicated_setting_type}};
		shift @remove_settings;
		for my $remove_setting (@remove_settings) {
			$client_data->delete_voice_setting($remove_setting->{'id'});
			$self->{'logger'}->register_category('duplicated '.$remove_settings[0]{'reminder_type'});
		}
	}

	if (@$settings) {
		unless (exists $non_appointment_settings{'fake_reminder'}) {
			$client_data->add_voice_setting('fake_reminder', '&mdash;Not assigned&mdash;', 0);
			$self->{'logger'}->register_category('restore fake_reminder');
		}
	} else {
		$self->{'logger'}->register_category('settings are missing');
	}
}

1;