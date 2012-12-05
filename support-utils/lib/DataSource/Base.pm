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

    return [ sort map {$_->{'sql'}} @{ $self->{'statements'} } ];
}

sub save_sql_commands_to_file {
	my ($self, $file_name, $filter_re) = @_;

	my $statements = $self->{'statements'};
	if (defined $filter_re) {
		$statements = [ grep { $_->{'sql'} =~ m/$filter_re/ } @$statements ];
	}

	open(my $fh, '>', $file_name) or die "can't write [$file_name]: $!";
	if (@$statements) {
		print $fh "-- $file_name\n";
		for my $sql (sort @$statements) {
			(my $sql_cmd = $sql->{'sql'}) =~ s/\s+$//;
			print $fh "$sql_cmd;".(defined $sql->{'comment'} ? " -- ".$sql->{'comment'} : "")."\n";
		}
	}
	close($fh);
}

sub add_statement {
	my ($self, $sql, $comment) = @_;

	if (defined $comment) {
		$comment =~ s/\s+/ /g;
		$comment =~ s/^\s+|\s+$//g;
	}
	push(
        @{ $self->{'statements'} },
        {
        	'sql' => $sql,
        	'comment' => $comment,
        }
	);
}


1;