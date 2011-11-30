## $Id$
package Migrate::Custom;

use strict;
use warnings;

use base qw( Migrate::Base );

sub new {
	my ($class, $name, $methods, $key_fields) = @_;

	my $self = $class->SUPER::new();
	$self->{'name'} = $name;
	$self->{'methods'} = $methods;
	$self->{'key_fields'} = $key_fields;
	return $self;
}

sub _method_name {
	my ($self, $method) = @_;

	return $self->{'methods'}{$method};
}

sub _get_name {
	my ($self) = @_;

	return $self->{'name'};
}

sub _generate_key {
	my ($self, $data) = @_;

	return join('|', @$data{ @{ $self->{'key_fields'} } });
}

1;