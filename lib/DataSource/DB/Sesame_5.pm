## $Id$
package DataSource::DB::Sesame_5;

use strict;
use warnings;

use File::Spec;

#use Sesame::Unified::Client;
#use Sesame::Unified::ClientProperties;

use base qw( DataSource::DB );

sub get_client_data_by_db {
    my ($self, $db) = @_;

    require ClientData::DB::Sesame_5;
    return ClientData::DB::Sesame_5->new($self, $db, $self->{'dbh'});
}

sub get_client_data_by_id {
    my ($self, $id) = @_;

    require ClientData::DB::Sesame_5;
    return ClientData::DB::Sesame_5->new_by_id($self, $id, $self->{'dbh'});
}

sub get_client_data_for_all {
	my ($self) = @_;

    require ClientData::DB::Sesame_5;
	return [
		map { ClientData::DB::Sesame_5->new($self, $_->get_username(), $self->{'dbh'}, $_)  }
		@{ Sesame::Unified::Client->get_all_clients() }
	];
}

sub get_all_case_numbers {
	my ($self) = @_;

	return $self->{'dbh'}->selectcol_arrayref(<<'SQL');
SELECT case_number FROM invisalign_case_process_patient
UNION
SELECT case_num AS case_number FROM invisalign_patient
SQL
}

sub get_invisalign_client_ids_by_case_number {
	my ($self, $case_number) = @_;

	return $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT invisalign_client_id FROM invisalign_patient WHERE case_num=?
SQL
}

sub get_invisalign_processing_client_ids_by_case_number {
	my ($self, $case_number) = @_;

	return $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT invisalign_client_id FROM invisalign_case_process_patient WHERE case_number=?
SQL
}

sub get_client_id_by_invisalign_id {
	my ($self, $invisalign_id) = @_;

	return scalar $self->{'dbh'}->selectrow_array(<<'SQL', undef, $invisalign_id);
SELECT client_id FROM invisalign_client WHERE id=?
SQL
}

sub get_all_clincheck_files {
	my ($self) = @_;

	return $self->_get_all_clincheck_files(
		File::Spec->join(
	    	$ENV{'SESAME_COMMON'},
	    	'invisalign-cases',
	    )
	);
}

1;