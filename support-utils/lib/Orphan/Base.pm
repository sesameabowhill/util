## $Id$
package Orphan::Base;

use strict;
use warnings;

sub new {
	my ($class, $logger) = @_;

	return bless {
		'logger' => $logger,
	}, $class;
}

sub clear_orphan_data {
	my ($self, $data_source) = @_;

	my $method_get_list = $self->method_get_list();
	printf("get orphan %s\n", $self->get_name());
	my $orphan_data_ids = $data_source->$method_get_list();

	printf(
		"found [%d] orphan %s record%s\n",
		scalar @$orphan_data_ids,
		$self->get_name(),
		( @$orphan_data_ids == 1 ? '' : 's' ),
	);
	my $method_delete_item = $self->method_delete_item();
	my $record_count = 0;
	my $digits_length = length scalar @$orphan_data_ids;
	## force to print first action
	my $print_time = time()-1;
	for my $record_id (@$orphan_data_ids) {
		$data_source->$method_delete_item($record_id);
		$record_count ++;
		if ($record_count == @$orphan_data_ids) {
			## force to print last action
			$print_time --;
		}
		if (time() - $print_time > 0) {
			$print_time = time();
			printf(
				"DELETE %${digits_length}d/%d record\n",
				$record_count,
				scalar @$orphan_data_ids,
			);
		}
	}
}

1;