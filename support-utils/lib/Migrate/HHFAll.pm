## $Id$
package Migrate::HHFAll;

use strict;
use warnings;

use Migrate::Custom;

sub new {
	my ($class) = @_;

	return bless {
	}, $class;
}

sub migrate {
	my ($class, $client_data_5, $client_data_4) = @_;

	my @migrators = (
		Migrate::HHFForms->new(),
		Migrate::Custom->new(
			'hhf_settings',
			{
				'old_list' => 'get_hhf_settings',
				'new_list' => 'get_hhf_settings',
				'add_new'  => 'add_hhf_setting',
			},
			[ 'PKey' ],
		),
		Migrate::Custom->new(
			'hhf_client_setting',
			{
				'old_list' => 'get_hhf_client_settings',
				'new_list' => 'get_hhf_client_settings',
				'add_new'  => 'add_hhf_client_setting',
			},
			[ 'guid' ],
		),
		Migrate::Custom->new(
			'hhf_template',
			{
				'old_list' => 'get_hhf_templates',
				'new_list' => 'get_hhf_templates',
				'add_new'  => 'add_hhf_template',
			},
			[ 'body_exists' ],
		),
	);

	for my $migrator (@migrators) {
		unless ($migrator->migrate($client_data_5, $client_data_4)) {
			return 0;
		}
	}
	return 1;
}

1;