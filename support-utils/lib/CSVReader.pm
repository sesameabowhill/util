## $Id$
package CSVReader;

use strict;
use warnings;

use Text::CSV;
use Hash::Util qw( lock_keys );

sub new {
	my ($class, $file_name, $columns, $sep_char, $key_mapper) = @_;

    my $csv = Text::CSV->new(
        {
            'escape_char' => '"',
            'sep_char' => (defined $sep_char ? $sep_char : ','),
            'quote_char' => '"',
        }
    );

    open(my $fh, "<:utf8", $file_name) or die "can't read [$file_name]: $!";
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
		'key_mapper' => $key_mapper,
#		'columns' => $columns,
	}, $class;
}

sub get_next_item {
	my ($self) = @_;

	my $line = $self->{'csv'}->getline_hr( $self->{'fh'} );
	if (defined $line) {
		if (defined $self->{'key_mapper'}) {
			my %new_line;
			for my $k (keys %$line) {
				if (exists $self->{'key_mapper'}{$k}) {
					$new_line{ $self->{'key_mapper'}{$k} } = $line->{$k};
				}
				else {
					$new_line{$k} = $line->{$k};
				}
			}
			$line = \%new_line;
		}
    	lock_keys(%$line);
	}
    return $line;
}

sub get_all_data {
    my ($self) = @_;

    my @data;
    while (my $line = $self->get_next_item()) {
        push(@data, $line);
    }
    return \@data;
}


DESTROY {
	my ($self) = @_;

	close( $self->{'fh'} );
}


1;