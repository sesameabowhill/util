## $Id$

package CSVWriter;

use strict;
use warnings;

sub new {
	my ($class, $file_name, $columns) = @_;

	open(my $fh, '>', $file_name) or die "can't write [$file_name]: $!";
	{
		my $cur_fh = select($fh);
		$| = 1;
		select($cur_fh);
	}
	print $fh join(';', @$columns)."\n";

	return bless {
		'fh' => $fh,
		'file_name' => $file_name,
		'columns' => $columns,
	}, $class;
}

sub write_item {
	my ($self, $item) = @_;

	my $fh = $self->{'fh'};
	print $fh join(';', @$item{ @{ $self->{'columns'} } })."\n";
}


sub write_data {
	my ($self, $data) = @_;

	for my $d (@$data) {
		$self->write_item($d);
	}
}

sub get_file_name {
	my ($self) = @_;

	return $self->{'file_name'};
}

DESTROY {
	my ($self) = @_;

	close( $self->{'fh'} );
}

1;