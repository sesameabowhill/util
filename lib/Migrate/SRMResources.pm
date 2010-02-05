## $Id$
package Migrate::SRMResources;

use strict;
use warnings;

use base qw( Migrate::Base );

sub _method_name {
	my ($class, $method) = @_;

	my %methods = (
		'old_list' => 'get_all_srm_resources',
		'new_list' => 'get_all_srm_resources',
		'add_new'  => 'add_new_srm_resource',
	);
	return $methods{$method};
}

sub _get_name {
	my ($class) = @_;

	return 'resources';
}

sub _generate_key {
	my ($class, $data) = @_;

	return $data->{'id'};
}


1;