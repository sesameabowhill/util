## $Id$

package ClientData::PMSMigrationBackup;

use strict;
use warnings;

use File::Spec;

use CSVReader;

use base 'ClientData::Base';

sub new {
	my ($class, $backup_folder, $username) = @_;

	my $self = $class->SUPER::new();
	$self->{'backup_folder'} = $backup_folder;
	$self->{'username'} = $username;
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

sub _new_csv_reader {
	my ($self, $table) = @_;

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
		$key_mappers{$table},
	);
}

1;