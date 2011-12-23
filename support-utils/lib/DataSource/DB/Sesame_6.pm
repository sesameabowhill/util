package DataSource::DB::Sesame_6;

use strict;
use warnings;

use File::Spec;

use base qw( DataSource::DB::Sesame_5 );

sub get_client_data_by_db {
    my ($self, $db, $force_type) = @_;

    require ClientData::DB::Sesame_6;
    return ClientData::DB::Sesame_6->new($self, $db, $self->{'dbh'}, $force_type);
}

sub get_client_data_by_id {
    my ($self, $id) = @_;

    require ClientData::DB::Sesame_6;
    return ClientData::DB::Sesame_6->new_by_id($self, $id, $self->{'dbh'});
}

1;
