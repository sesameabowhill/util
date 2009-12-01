## $Id$
package CSVReader;

use strict;
use warnings;

use Text::CSV_XS;
use Hash::Util qw( lock_keys );

sub new {
	my ($class, $file_name, $columns, $sep_char) = @_;

    my $csv = Text::CSV_XS->new(
        {
            'escape_char' => '"',
            'sep_char' => (defined $sep_char ? $sep_char : ','),
            'quote_char' => '"',
        }
    );

    open(my $fh, "<", $file_name) or die "can't read [$file_name]: $!";
    if (defined $columns) {
    	$csv->column_names(@$columns);
    }
    else {
    	$csv->column_names(
    		$csv->getline($fh)
    	);
    }

	return bless {
		'fh' => $fh,
		'csv' => $csv,
#		'columns' => $columns,
	}, $class;
}

sub get_all_data {
    my ($self) = @_;

    my @data;
    while (my $line = $self->{'csv'}->getline_hr( $self->{'fh'} )) {
    	lock_keys(%$line);
        push(@data, $line);
    }
    return \@data;
}


DESTROY {
	my ($self) = @_;

	close( $self->{'fh'} );
}


1;