#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use lib qw( ../lib );

use CSVReader;

my (@files) = @ARGV;
if (@files > 1) {
	my $start_time = time();
	my $output_file = shift @files;
	print "output to [$output_file]\n";
	my $writer = SQLWriter->new($output_file);
	for my $file (@files) {
		print "reading file [$file]\n";
		my $reader = CSVReader->new($file);
		while (my $line = $reader->get_next_item()) {
			$writer->write_item($line);
		}
	}
#	print "sorting records\n";
#	@data = sort {$a->{'ZIP_CODE'} cmp $b->{'ZIP_CODE'}} @data;
	printf "[%d] records saved\n", $writer->get_count();
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 <output.sql> <csv_file1> ...\n";
	exit(1);
}

package SQLWriter;

sub new {
	my ($class, $output_file) = @_;

	open(my $output_fh, '>', $output_file) or die "can't write [$output_file]: $!";
	print $output_fh "-- Dumping data for table \`ZipCodeArea\`\n--\n\n";
	print $output_fh "DELETE FROM ZipCodeArea;\n\n";

	return bless {
		'output_fh' => $output_fh,
		'used_zip' => {},
		'count' => 0,
	}, $class;
}

sub get_count {
	my ($self) = @_;

	return $self->{'count'};
}

sub write_item {
	my ($self, $r) = @_;

	my ($state_field, $zip_field) = (
		exists $r->{'POSTAL_CODE'} ?
			( 'PROVINCE_ABBR', 'POSTAL_CODE' ) :
			( 'STATE', 'ZIP_CODE' )
	);
	unless (exists $self->{'used_zip'}{ $r->{$zip_field} }) {
		$self->{'used_zip'}{ $r->{$zip_field} } = 1;

		if ($r->{'AREA_CODE'} =~ m{(\d+)/(\d+)}) {
			$r->{'AREA_CODE'} = $2;
		}
		$self->{'count'}++;
		my $output_fh = $self->{'output_fh'};
		print $output_fh (
			"INSERT INTO ZipCodeArea (area_code, ZIP, city, state) VALUES (" .
				join(', ',
					map { sql_quote($_) }
					@$r{'AREA_CODE', $zip_field, 'CITY', $state_field}
				) .
			");\n"
		);
	}
}

sub sql_quote {
	my ($str) = @_;

	$str =~ s/\\/\\\\/g;
	$str =~ s/"/\\"/g;
	return qq("$str");
}

DESTROY {
	my ($self) = @_;

	close( $self->{'output_fh'} );
}
