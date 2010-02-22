## $Id$
package ClientData::DB;

use strict;
use warnings;

my %PROFILE_COLUMN_TYPE_ID = (
	'1'  => 'SVal',
	'2'  => 'IVal',
	'4'  => 'RVal',
	'8'  => 'DVal',
	'16' => 'TVal',
);

sub new {
	my ($class, $data_source, $db_name, $unified_client_ref) = @_;

	my $self = bless {
		'data_source' => $data_source,
		'approx_search' => 0,
		'client_ref' => $unified_client_ref,
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
	if ($self->{'approx_search'} > 0) {
		unless (@$result) {
			if (defined $lname) {
				$result = $self->{'dbh'}->selectall_arrayref(
					"SELECT $fields FROM $table WHERE CONCAT($fname_field, ' ', $lname_field) RLIKE ?$where",
					{ 'Slice' => {} },
					$self->_string_to_rlike("$fname $lname"),
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

sub _string_to_rlike {
	my ($self, $str) = @_;

	$str =~ s/\b/ /g;
	$str =~ s/\s+/.*/g;
	$str =~ s/\b(?=\w)/[[:<:]]/g;
	return $str;
}

sub _get_profile_value {
	my ($self, $key, $table, $where) = @_;

	my $value = $self->{'dbh'}->selectall_arrayref(
		"SELECT	Type, SVal, IVal, RVal, DVal, TVal FROM $table WHERE PKey=? $where",
		{ 'Slice' => {} },
		$key,
	)->[0];
	if (defined $value) {
		return $value->{ $PROFILE_COLUMN_TYPE_ID{ $value->{'Type'} } };
	}
	else {
		return undef;
	}
}

sub _get_invisalign_quotes_ids {
	my ($self, $case_number) = @_;

	my $inv_client_ids = $self->_get_invisalign_client_ids();

	if (@$inv_client_ids) {
		return join(
        	", ",
        	map { $self->{'dbh'}->quote($_) } @$inv_client_ids
		);
	}
	else {
		return "";
	}
}

1;