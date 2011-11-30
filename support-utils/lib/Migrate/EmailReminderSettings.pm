## $Id$
package Migrate::EmailReminderSettings;

use strict;
use warnings;

use base qw( Migrate::Base );

sub _method_name {
	my ($class, $method) = @_;

	my %methods = (
		'old_list' => 'get_email_reminder_settings',
		'new_list' => 'get_email_reminder_settings',
		'add_new'  => 'add_new_reminder_setting',
	);
	return $methods{$method};
}

sub _get_name {
	my ($class) = @_;

	return 'settings';
}

sub _generate_key {
	my ($class, $data) = @_;

	if ($data->{'type'} eq 'standard') {
		return $data->{'type'}.'|'.$data->{'subject'};
	}
	else {
		return $data->{'type'};
	}
}


1;