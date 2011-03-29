## $Id$
package Repair::Base;

use strict;
use warnings;

sub new {
	my ($class, $logger) = @_;

	return bless {
		'logger' => $logger,
	}, $class;
}

sub get_commands_extension {
	my ($self) = @_;

	return undef;
}

1;