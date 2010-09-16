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
	my ($self, $file_name) = @_;

	open(my $fh, '>', $file_name) or die "can't write [$file_name]: $!";
	if (@{ $self->{'statements'} }) {
		print $fh "-- $file_name\n";
		for my $sql_cmd (sort @{ $self->{'statements'} }) {
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