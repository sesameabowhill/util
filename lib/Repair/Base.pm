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

1;