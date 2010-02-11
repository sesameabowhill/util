#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use Getopt::Long;
use List::MoreUtils qw( each_array );

use lib qw( ../lib );

use CSVReader;

my @input_files;
my @output_file;
my @table_name;
my @important_zip;
GetOptions(
	'input=s'         => \@input_files,
	'table=s'         => \@table_name,
	'output=s'        => \@output_file,
	'important-zip=s' => \@important_zip,
);

$|=1;

push(@input_files, @ARGV);
if (@input_files > 1 && @output_file > 0 && @table_name == @output_file) {
	my $start_time = time();
	#my $output_file = shift @files;

	my @writers;
	my $writer_iter = each_array(@table_name, @output_file);
	while (my ($table, $file) = $writer_iter->()) {
		print "output table [$table] to [$file]\n";
		push(
			@writers,
			SQLWriter->new($file, $table),
		);
	}
	my %important_zips = map {$_ => 1} @important_zip;
	for my $file (@input_files) {
		print "reading file [$file]\n";
		my $reader = CSVReader->new($file);
		while (my $line = $reader->get_next_item()) {
			for my $writer (@writers) {
				$writer->write_item($line, \%important_zips);
			}
		}
	}
	printf "[%d] records saved\n", $writers[0]->get_count();
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 --input=<input_file> --table=<table_name> --output=<output.sql> --important-zip=[zip] <input_file> ...\n";
	exit(1);
}

package SQLWriter;

sub new {
	my ($class, $output_file, $table_name) = @_;

	open(my $output_fh, '>', $output_file) or die "can't write [$output_file]: $!";
	print $output_fh "-- Dumping data for table \`$table_name\`\n--\n\n";
	print $output_fh "/*!40000 ALTER TABLE `$table_name` DISABLE KEYS */;\n";
	print $output_fh "TRUNCATE TABLE `$table_name`;\n\n";

	return bless {
		'output_fh' => $output_fh,
		'used_zip' => {},
		'count' => 0,
		'current_query' => [],
		'current_size' => 0,
		'max_query_size' => 150_000,
		'table_name' => $table_name,
	}, $class;
}

sub get_count {
	my ($self) = @_;

	return $self->{'count'};
}

#"79705","MIDLAND","TX","*432/915"
#"60525","LA GRANGE","IL","630/*708"


sub write_item {
	my ($self, $r, $important_zips) = @_;

	my ($state_field, $zip_field) = (
		exists $r->{'POSTAL_CODE'} ?
			( 'PROVINCE_ABBR', 'POSTAL_CODE' ) :
			( 'STATE', 'ZIP_CODE' )
	);
	unless (exists $self->{'used_zip'}{ $r->{$zip_field} }) {
		$self->{'used_zip'}{ $r->{$zip_field} } = 1;

		if ($r->{'AREA_CODE'} =~ m{(\d+)/(\d+)}) {
			my ($first_zip, $second_zip) = ($1, $2);
			if (exists $important_zips->{$first_zip}) {
				$r->{'AREA_CODE'} = $first_zip;
			}
			else {
				$r->{'AREA_CODE'} = $second_zip;
			}
		}
		$self->{'count'}++;
		$self->_print( @$r{'AREA_CODE', $zip_field, 'CITY', $state_field} );
	}
}

sub _print {
	my ($self, @values) = @_;

	if ($self->{'current_size'} > $self->{'max_query_size'}) {
		$self->_flush();
	}

	my $sql = "(" . join(', ', map { sql_quote($_) } @values ) . ")";
	unless (@{ $self->{'current_query'} }) {
		$sql = "INSERT INTO `".$self->{'table_name'}."` (area_code, ZIP, city, state) VALUES " . $sql;
	}
	push(@{ $self->{'current_query'} }, $sql);
	$self->{'current_size'} += length $sql;
}

sub _flush {
	my ($self) = @_;

	if (@{ $self->{'current_query'} }) {
		my $output_fh = $self->{'output_fh'};
		print $output_fh join(', ', @{ $self->{'current_query'} }).";\n";
		$self->{'current_query'} = [];
		$self->{'current_size'} = 0;
	}
}

sub sql_quote {
	my ($str) = @_;

	if ($str =~ m/^[1-9]\d*$/) {
		return $str;
	}
	else {
		$str =~ s/\\/\\\\/g;
		$str =~ s/"/\\"/g;
		return qq("$str");
	}
}

DESTROY {
	my ($self) = @_;

	$self->_flush();

	my $output_fh = $self->{'output_fh'};
	print $output_fh "\n/*!40000 ALTER TABLE `".$self->{'table_name'}."` ENABLE KEYS */;\n";

	close( $self->{'output_fh'} );
}
