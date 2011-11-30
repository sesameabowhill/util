## $Id$
package Repair::HolidaySettings;

use strict;
use warnings;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my $settings = $client_data->get_all_holiday_settings();
	my %setting_by_holiday;
	for my $setting (sort { $b->{'id'} <=> $a->{'id'} } @$settings) {
		if (exists $setting_by_holiday{ $setting->{'holiday_id'} }){
			$self->{'logger'}->printf_slow(
				"DELETE [%s]: setting [%d] for holiday [%d] is duplicated",
				$client_data->get_username(),
				$setting->{'id'},
				$setting->{'holiday_id'},
			);
			$self->{'logger'}->register_category('duplicated setting (delete)');
			$client_data->delete_holiday_setting($setting->{'id'});
		}
		else {
			$setting_by_holiday{ $setting->{'holiday_id'} } = $setting;
			$self->{'logger'}->register_category('one setting per holiday');
		}
	}
}

1;