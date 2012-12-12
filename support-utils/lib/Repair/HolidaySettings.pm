## $Id$
package Repair::HolidaySettings;

use strict;
use warnings;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my %holiday_dates = map { $_->{'id'} => $_ } @{ $client_data->get_all_holidays() };

	my $settings = $client_data->get_all_holiday_settings();
	my %setting_by_holiday;
	unless (@$settings) {
		$self->{'logger'}->register_category('no holiday settings');
	}
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
		if ($setting->{'date'} =~ m{-00-00$}) {
			if (exists $holiday_dates{$setting->{'holiday_id'}}) {
				$client_data->update_holiday_setting_date($setting->{'id'}, $holiday_dates{$setting->{'holiday_id'}}{'date'});
				$self->{'logger'}->register_category('fix setting date for '.$holiday_dates{$setting->{'holiday_id'}}{'name'});
			} else {
				$self->{'logger'}->register_category('default date is missing for '.$setting->{'holiday_id'});
			}
		}
	}
}

1;