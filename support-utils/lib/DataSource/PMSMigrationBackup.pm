## $Id$

package DataSource::PMSMigrationBackup;

use strict;
use warnings;

use File::Spec;

use base 'DataSource::Base';

sub new {
	my ($class) = @_;

	return bless {
		'backup_folder' => File::Spec->join($ENV{'SESAME_COMMON'}, 'storage', 'pms_migration'),
		'read_only' => 1,
		'statements' => [],
	}, $class;
}

sub get_connection_info {
	my ($self) = @_;

	return 'backup files from "'.$self->{'backup_folder'}.'"';
}

sub get_client_data_by_db {
	my ($self, $username) = @_;

	my $backup_folder = File::Spec->join( $self->{'backup_folder'}, $username, 'backup');
	if (-d $backup_folder) {
		require ClientData::PMSMigrationBackup;
		return ClientData::PMSMigrationBackup->new($self, $backup_folder, $username);
	}
	else {
		die "can't find [$username] backup folder [$backup_folder]";
	}
}

1;