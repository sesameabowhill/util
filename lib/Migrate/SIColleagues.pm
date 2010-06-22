## $Id$
package Migrate::SIColleagues;

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

# pms_referrings		=> referrer
# referrings			=> referrer
# referring_contacts	=> referrer
# SI_Doctor				=> si_doctor

	my @migrators = (
		Migrate::Custom->new(
			'hhf_settings',
			{
				'old_list' => 'get_hhf_settings',
				'new_list' => 'get_hhf_settings',
				'add_new'  => 'add_hhf_setting',
			},
			[ 'PKey' ],
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