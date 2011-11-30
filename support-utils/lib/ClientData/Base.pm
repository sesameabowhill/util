## $Id$
package ClientData::Base;

use strict;
use warnings;


sub new {
	my ($class) = @_;

	my $self = bless {
		'approx_search' => 0,
		'cached_data' => {},
	}, $class;

	return $self;
}

sub set_approx_search {
	my ($self, $level) = @_;

	$self->{'approx_search'} = $level;
}

sub get_cached_data {
	my ($self, $key, $generate_cache_sub) = @_;

	unless (exists $self->{'cached_data'}{$key}) {
		$self->{'cached_data'}{$key} = $generate_cache_sub->();
	}
	return $self->{'cached_data'}{$key};
}


1;