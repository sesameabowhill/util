#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use Getopt::Long;
use List::MoreUtils 'each_array';
use List::Util 'sum';

use lib qw( ../lib );

use CSVReader;

my @input_files;
my @input_columns;
my @output_file;
my @table_name;
my @important_area_code;
GetOptions(
	'input=s'         => \@input_files,
	'input-columns=s' => \@input_columns,
	'table=s'         => \@table_name,
	'output=s'        => \@output_file,
	'important-area-code=s' => \@important_area_code,
);

$|=1;

push(@input_files, @ARGV);
if (@input_files > 1 && @output_file > 0 && @table_name == @output_file) {
	my $start_time = time();
	#my $output_file = shift @files;

    my %important_area_codes = map {$_ => 1} @important_area_code;
	my @writers;
	my $writer_iter = each_array(@table_name, @output_file);
	while (my ($table, $file) = $writer_iter->()) {
		print "output table [$table] to [$file]\n";
		push(
			@writers,
			SQLWriter->new($file, $table, \%important_area_codes),
		);
	}
	my $input_iter = each_array(@input_files, @input_columns);
    while (my ($file, $columns_str) = $input_iter->()) {
		print "reading file [$file]\n";
		my $columns = parse_columns_string($columns_str);
		my $reader = CSVReader->new($file);
		while (my $line = $reader->get_next_item()) {
			for my $writer (@writers) {
				$writer->write_item($line, $columns);
			}
		}
	}
    for my $code (sort {$a <=> $b} keys %important_area_codes) {
        my $use_count = sum map { $_->get_area_code_use_count($code) } @writers;
        printf(
            "area code [%d] %s\n",
            $code,
            ($use_count == 0 ? "not used" :
                ($use_count == 1 ? "used 1 time" : "used $use_count times"))
        );
    }

	printf "[%d] records saved\n", $writers[0]->get_count();
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 --input=<input_file> --input-columns=zip,area,city,state --table=<table_name> --output=<output.sql> --important-area-code=[area-code] <input_file> ...\n";
	exit(1);
}

sub parse_columns_string {
    my ($str) = @_;

    unless (defined $str && $str =~ m{,}) {
        die "invalid input-columns [$str]";
    }
    return [ map { trim($_) } split ',', $str ];
}

sub trim {
	my ($str) = @_;

    $str =~ s/^\s+|\s+$//g;
	return $str;
}

package SQLWriter;

sub new {
	my ($class, $output_file, $table_name, $important_area_codes) = @_;

	open(my $output_fh, '>', $output_file) or die "can't write [$output_file]: $!";
	print $output_fh "-- Dumping data for table \`$table_name\`\n--\n\n";
	print $output_fh "/*!40000 ALTER TABLE `$table_name` DISABLE KEYS */;\n";
	print $output_fh "TRUNCATE TABLE `$table_name`;\n\n";

	return bless {
		'output_fh' => $output_fh,
		'used_zip' => {},
		'used_area_code' => {},
		'count' => 0,
		'current_query' => [],
		'current_size' => 0,
		'max_query_size' => 150_000,
		'table_name' => $table_name,
		'important_area_codes' => $important_area_codes,
	}, $class;
}

sub get_count {
	my ($self) = @_;

	return $self->{'count'};
}

#"79705","MIDLAND","TX","*432/915"
#"60525","LA GRANGE","IL","630/*708"


sub write_item {
	my ($self, $r, $columns) = @_;

	my ($zip_field, $area_field, $city_field, $state_field) = @$columns;
	if (defined $r->{$area_field} && length $r->{$area_field}) {
        unless (exists $self->{'used_zip'}{ $r->{$zip_field} }) {
            $self->{'used_zip'}{ $r->{$zip_field} } = 1;

            if ($r->{$area_field} =~ m{(\d+)/(\d+)}) {
                my ($first_zip, $second_zip) = ($1, $2);
                if (exists $self->{'important_area_codes'}{$first_zip}) {
                    $r->{$area_field} = $first_zip;
                }
                else {
                    $r->{$area_field} = $second_zip;
                }
            }
            $self->{'used_area_code'}{ $r->{$area_field} } ++;

            $self->{'count'}++;
            $self->_print( @$r{$area_field, $zip_field, $city_field, $state_field} );
        }
	}
	else {
	    print "skip empty area code record\n";
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

sub get_area_code_use_count {
	my ($self, $area_code) = @_;

    return $self->{'used_area_code'}{$area_code};
}

DESTROY {
	my ($self) = @_;

	$self->_flush();

	my $output_fh = $self->{'output_fh'};
	print $output_fh "\n/*!40000 ALTER TABLE `".$self->{'table_name'}."` ENABLE KEYS */;\n";

	close( $self->{'output_fh'} );
}
