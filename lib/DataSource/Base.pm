## $Id$
package DataSource::Base;

use strict;
use warnings;

sub set_read_only {
	my ($self, $flag) = @_;

	$self->{'read_only'} = $flag;
}

sub is_read_only {
	my ($self) = @_;

	return $self->{'read_only'};
}

sub get_statements {
    my ($self) = @_;

    return [ sort @{ $self->{'statements'} } ];
}

sub save_sql_commands_to_file {
	my ($self, $file_name, $filter_re) = @_;

	my $statements = $self->{'statements'};
	if (defined $filter_re) {
		$statements = [ grep { m/$filter_re/ } @$statements ];
	}

	open(my $fh, '>', $file_name) or die "can't write [$file_name]: $!";
	if (@$statements) {
		print $fh "-- $file_name\n";
		for my $sql_cmd (sort @$statements) {
			$sql_cmd =~ s/\s+$//;
			print $fh "$sql_cmd;\n";
		}
	}
	close($fh);
}

sub add_statement {
	my ($self, $sql) = @_;

	push(
        @{ $self->{'statements'} },
        $sql,
	);
}


1;