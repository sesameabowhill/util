## $Id$
package ClientData::DB;

use strict;
use warnings;

use Sesame::Unified::Client;


sub new {
	my ($class, $data_source, $db_name) = @_;

	my $client_ref = Sesame::Unified::Client->new('db_name', $db_name);

	my $self = bless {
		'data_source' => $data_source,
		'strict_search' => 1,
		'client_ref' => $client_ref,
		'cached_data' => {},
	}, $class;

	return $self;
}


sub get_db_name {
	my ($self) = @_;

	return $self->{'client_ref'}->get_db_name();
}

sub set_strict_level {
	my ($self, $level) = @_;

	$self->{'strict_search'} = $level;
}

sub is_active {
	my ($self) = @_;

	return $self->{'client_ref'}->is_active();
}

sub get_cached_data {
	my ($self, $key, $generate_cache_sub) = @_;

	unless (exists $self->{'cached_data'}{$key}) {
		$self->{'cached_data'}{$key} = $generate_cache_sub->();
	}
	return $self->{'cached_data'}{$key};
}

sub _search_with_fields_by_name {
	my ($self, $fields, $fname_field, $lname_field, $table, $fname, $lname, $where) = @_;

	if (defined $where) {
		$where = " AND $where";
	}
	else {
		$where = '';
	}
	my $result;
	if (defined $lname) {
		$result = $self->{'dbh'}->selectall_arrayref(
			"SELECT $fields FROM $table WHERE $fname_field=? AND $lname_field=?$where",
			{ 'Slice' => {} },
			$fname, $lname
		);
	}
	else {
		$result = $self->{'dbh'}->selectall_arrayref(
			"SELECT $fields FROM $table WHERE CONCAT($fname_field, ' ', $lname_field)=?$where",
			{ 'Slice' => {} },
			$fname
		);
	}
	unless ($self->{'strict_search'}) {
		unless (@$result) {
			if (defined $lname) {
				$result = $self->{'dbh'}->selectall_arrayref(
					"SELECT $fields FROM $table WHERE CONCAT($fname_field, ' ', $lname_field) LIKE ?$where",
					{ 'Slice' => {} },
					$self->_string_to_like("$fname $lname"),
				);
			}
			else {
				$result = $self->{'dbh'}->selectall_arrayref(
					"SELECT $fields FROM $table WHERE ? LIKE CONCAT('%', $fname_field, ' ', $lname_field,'%')$where",
					{ 'Slice' => {} },
					$fname,
				);
			}
		}
	}
	return $result;
}

sub _string_to_like {
	my ($self, $str) = @_;

	$str =~ s/\b/ /g;
	$str =~ s/\s+/%/g;
	return $str;
}

1;