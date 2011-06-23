## $Id$

package ClientData::PMSMigrationBackup;

use strict;
use warnings;

use File::Spec;

use CSVReader;

use base 'ClientData::Base';

sub new {
	my ($class, $data_source, $backup_folder, $username) = @_;

	my $self = $class->SUPER::new();
	$self->{'backup_folder'} = $backup_folder;
	$self->{'username'} = $username;
	$self->{'data_source'} = $data_source;
	return $self;
}

sub get_full_type {
	my ($self) = @_;

	return 'sesame';
}

sub get_username {
	my ($self) = @_;

	return $self->{'username'};
}

sub get_all_emails {
	my ($self) = @_;

	my $reader = $self->_new_csv_reader('email');
	return $reader->get_all_data();
}

sub get_all_phones {
	my ($self) = @_;

	my $reader = $self->_new_csv_reader('phone');
	return $reader->get_all_data();
}

sub get_visitor_by_id {
	my ($self, $visitor_id) = @_;

	my $visitor_by_id = $self->get_cached_data(
		'visitor_by_id',
		sub {
			my $reader = $self->_new_csv_reader('visitor');
			my $all_visitors = $reader->get_all_data();
			my %visitor_by_id;
			for my $visitor (@$all_visitors) {
				$visitor_by_id{ $visitor->{'id'} } = $visitor;
			}
			return \%visitor_by_id;
		},
	);
	return $visitor_by_id->{$visitor_id};
}

sub dump_table_data {
	my ($self, $table_name, $table_id, $columns, $where, $logger) = @_;

	my $escaped_table_name = '`'.$table_name.'`';
	my $reader = $self->_new_csv_reader($table_name, 1);

	while (my $r = $reader->get_next_item()) {
		if (defined $r->{$table_id} && length $r->{$table_id}) {
			my $update_sql = "UPDATE ".$escaped_table_name .
				" SET ". join(', ', map {'`'.$_.'`='.$self->_escape_data( $r->{$_} )} @$columns) .
				" WHERE client_id IN (SELECT id FROM client WHERE cl_username=" . $self->_escape_data( $self->{'username'} ) . ")".
				" AND ".$table_id."=".$self->_escape_data( $r->{$table_id} );
			if (defined $where) {
				$update_sql .= ' AND '.$where;
			}
			$update_sql .= ' LIMIT 1';
			$self->{'data_source'}->add_statement($update_sql);
			if ($logger) {
				$logger->printf_slow("save data for %s.%s='%s'", $table_name, $table_id, $r->{$table_id});
			}
		}
	}
}

sub _escape_data {
	my ($self, $str) = @_;

	if (defined $str) {
		$str =~ s/\\/\\\\/g;
		$str =~ s/(["'\r\n])/\\$1/g;
		return qq("$str");
	}
	else {
		return 'NULL';
	}
}

sub _new_csv_reader {
	my ($self, $table, $return_raw_columns) = @_;

	my %key_mappers = (
		'email' => {
			'email' => 'Email',
			'responsible_type' => 'BelongsTo',
			'relative_name' => 'Name',
			'date' => 'Date',
			'source' => 'Source',
			'deleted' => 'Deleted',
			'visitor_id' => 'VisitorId',
		},
		'visitor' => {
			'first_name' => 'FName',
			'last_name' => 'LName',
			'birthday' => 'BDate',
		},
	);

	return CSVReader->new(
		File::Spec->join( $self->{'backup_folder'}, $table.'.bkp' ),
		undef,
		"\t",
		( $return_raw_columns ? undef : $key_mappers{$table} ),
	);
}

1;