## $Id$
package DataSource::DB::Sesame_5;

use strict;
use warnings;

use Sesame::Unified::Client;
use Sesame::Unified::ClientProperties;

use base qw( DataSource::DB );

sub get_client_data_by_db {
    my ($self, $db) = @_;

    require ClientData::DB::Sesame_5;
    return ClientData::DB::Sesame_5->new($self, $db, $self->{'dbh'});
}

sub get_client_data_for_all {
	my ($self) = @_;

    require ClientData::DB::Sesame_5;
	return [
		map { ClientData::DB::Sesame_5->new($self, $_->get_username(), $self->{'dbh'}, $_)  }
		@{ Sesame::Unified::Client->get_all_clients() }
	];
}

1;