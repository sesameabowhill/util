## $Id$
package Repair::Base;

use strict;
use warnings;

sub new {
	my ($class) = @_;

	return bless {
	}, $class;
}

1;