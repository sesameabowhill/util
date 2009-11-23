## $Id$

package CSVWriter;

use strict;
use warnings;

sub new {
	my ($class, $file_name, $columns) = @_;

	open(my $fh, '>', $file_name) or die "can't write [$file_name]: $!";
	print $fh join(';', @$columns)."\n";
	
	return bless {
		'fh' => $fh,
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

DESTROY {
	my ($self) = @_;
	
	close( $self->{'fh'} );
}

1;