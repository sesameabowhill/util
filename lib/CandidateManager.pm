## $Id$
package CandidateManager;

use strict;
use warnings;

sub new {
	my ($class, $priorities) = @_;
	
	return bless {
		'candidates' => {},
		'priorities' => $priorities,
	}, $class;
}

sub add_candidate {
	my ($self, $priority, $params) = @_;
	
	unless (exists $self->{'priorities'}{$priority}) {
		die "unknow priority [$priority]";
	}
	
	push(
		@{ $self->{'candidates'}{$priority} },
		$params,	
	);
}

sub candidates_count_str {
	my ($self) = @_;
	
	my $priorities = $self->_get_candidate_priorities();
	if (@$priorities) {
		return join(', ', map {"$_ -> ".@{ $self->{'candidates'}{$_} }.' variants' } @$priorities);
	}
	else {
		return 'no variants';
	}
}

sub _get_candidate_priorities {
	my ($self) = @_;
	
	return [ 
		sort { $self->{'priorities'}{$a} <=> $self->{'priorities'}{$b} } 
		keys %{ $self->{'candidates'} } 
	];	
}

sub get_single_candidate {
	my ($self) = @_;
	
	my @priorities = 
		grep {1 == @{ $self->{'candidates'}{$_} }} 
		@{ $self->_get_candidate_priorities() };
	if (@priorities) {
		my $min_priority = $priorities[0];
		return $self->{'candidates'}{$min_priority}[0];		
	}
	return undef;
}

1;