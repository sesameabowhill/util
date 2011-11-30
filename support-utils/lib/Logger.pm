## $Id$

package Logger;

use strict;
use warnings;

sub new {
	my ($class) = @_;

	return bless {
		'categories' => {},
		'last_message_time' => undef,
		'last_skipped_message' => undef,
		'messages_skipped' => 0,
		'commands' => [],
	}, $class;
}

sub save_commands_to_file {
	my ($self, $fn) = @_;

	open(my $f, ">", $fn) or die "can't write [$fn]: $!";
	if (@{ $self->{'commands'} }) {
		print $f "## $fn\n";
		for my $cmd (@{ $self->{'commands'} }) {
			print $f "$cmd\n";
		}
	}
	close($f);
}

sub add_command {
	my ($self, $cmd) = @_;

	push(@{ $self->{'commands'} }, $cmd);
}

sub printf {
	my ($self, $pattern, @params) = @_;

	if (defined $self->{'last_skipped_message'}) {
		print($self->{'last_skipped_message'}."\n");
	}
	$self->{'messages_skipped'} = 0;
	$self->{'last_message_time'} = time() - 1;
	$self->{'last_skipped_message'} = undef;

	my $msg = sprintf($pattern, @params);
	print("$msg\n");
}

sub printf_slow {
	my ($self, $pattern, @params) = @_;

	my $msg = sprintf($pattern, @params);
	if (defined $self->{'last_message_time'}) {
		if ($self->{'messages_skipped'}) {
			$msg .= " (skipped ".$self->{'messages_skipped'}.")"
		}
		if ($self->{'last_message_time'} < time()) {
			$self->{'messages_skipped'} = 0;
			$self->{'last_message_time'} = time();
			$self->{'last_skipped_message'} = undef;
			print("$msg\n");
		}
		else {
			$self->{'last_skipped_message'} = $msg;
			$self->{'messages_skipped'} ++;
		}
	}
	else {
		$self->{'messages_skipped'} = 0;
		$self->{'last_message_time'} = time();
		$self->{'last_skipped_message'} = undef;
		print("$msg\n");
	}
}

sub register_category {
	my ($self, $category) = @_;

	$self->{'categories'}{$category} ++;
}

sub print_category_stat {
	my ($self) = @_;

	my $stat = $self->{'categories'};
	for my $category (sort keys %$stat) {
		$self->printf("%s - %d", $category, $stat->{$category});
	}
}

1;