## $Id: Base.pm 2096 2010-06-08 18:45:25Z ivan $
package Orphan::EmailContactLog;

use strict;
use warnings;

use base 'Orphan::Base';

sub method_get_list {
	my ($class) = @_;

	return 'get_orphan_email_contact_log_ids';
}

sub method_delete_item {
	my ($class) = @_;

	return 'delete_email_contact_log';
}

sub get_name {
	my ($class) = @_;

	return 'email_contact_log';
}

1;