## $Id$
package Migrate::Base;

use strict;
use warnings;

sub migrate {
	my ($class, $client_data_5, $client_data_4) = @_;

	my $old_list_method = $class->_method_name('old_list');
	my $new_list_method = $class->_method_name('new_list');
	my $old_list = $client_data_4->$old_list_method();
	my $current_list = $client_data_5->$new_list_method();
	printf(
		"CLIENT [%s]: [%d] old %s, [%d] new %s\n",
		$client_data_5->get_username(),
		scalar @$old_list,
		$class->_get_name(),
		scalar @$current_list,
		$class->_get_name(),
	);

	my %converted_items;
	for my $item (@$current_list) {
		$converted_items{ $class->_generate_key($item) } = 1;
	}

	my $add_new_method = $class->_method_name('add_new');

	for my $item (@$old_list) {
		my $unique_key = $class->_generate_key($item);
		unless (exists $converted_items{ $class->_generate_key($item) }) {
			printf(
				"CLIENT [%s]: copy [%s] %s\n",
				$client_data_5->get_username(),
				$unique_key,
				$class->_get_name(),
			);
			$client_data_5->$add_new_method($item);
		}
	}
}


1;