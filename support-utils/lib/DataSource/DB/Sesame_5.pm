## $Id$
package DataSource::DB::Sesame_5;

use strict;
use warnings;

use File::Spec;

use base qw( DataSource::DB );

sub get_client_data_by_db {
    my ($self, $db, $force_type) = @_;

    require ClientData::DB::Sesame_5;
    return ClientData::DB::Sesame_5->new($self, $db, $self->{'dbh'}, $force_type);
}

sub get_client_data_by_id {
    my ($self, $id) = @_;

    require ClientData::DB::Sesame_5;
    return ClientData::DB::Sesame_5->new_by_id($self, $id, $self->{'dbh'});
}

#sub get_client_data_by_ids {
#	my ($self, $client_ids) = @_;
#
#    require ClientData::DB::Sesame_5;
#	return [
#		map { ClientData::DB::Sesame_5->new_by_id($self, $_, $self->{'dbh'})  }
#		@$client_ids,
#	];
#}

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

sub _get_all_clients_username {
	my ($self, $active_only) = @_;

	my $where = ($active_only ?
		"cl_status=1" :
		"cl_status IN (0,1)"
	);
	return $self->{'dbh'}->selectcol_arrayref("SELECT cl_username FROM client WHERE $where ORDER BY 1");
}

sub get_all_srm_resources {
	my ($self) = @_;

	return $self->{'dbh'}->selectall_arrayref(
		"SELECT id, container, date, path_from, type, description FROM srm_resource",
		{ 'Slice' => {} },
	);
}

sub get_orphan_sent_mail_log_ids {
	my ($self) = @_;

	return $self->{'dbh'}->selectcol_arrayref(
		'SELECT l.id FROM email_sent_mail_log l LEFT JOIN visitor v ON (v.id=l.visitor_id) WHERE isnull(v.id)',
		undef
	);
}

sub delete_sent_mail_log {
	my ($self, $id) = @_;

	$self->_do_query(<<'SQL', [ $id ]);
DELETE FROM email_sent_mail_log WHERE id=%s LIMIT 1
SQL
}

sub get_orphan_email_contact_log_ids {
	my ($self) = @_;

	return $self->{'dbh'}->selectcol_arrayref(
		'SELECT l.id FROM email_contact_log l LEFT JOIN visitor v ON (v.id=l.visitor_id) WHERE isnull(v.id)',
		undef
	);
}

sub delete_email_contact_log {
	my ($self, $id) = @_;

	$self->_do_query(<<'SQL', [ $id ]);
DELETE FROM email_contact_log WHERE id=%s LIMIT 1
SQL
}



1;