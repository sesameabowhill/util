## $Id$
package Orphan::SentMailLog;

use strict;
use warnings;

use base 'Orphan::Base';

sub method_get_list {
	my ($class) = @_;

	return 'get_orphan_sent_mail_log_ids';
}

sub method_delete_item {
	my ($class) = @_;

	return 'delete_sent_mail_log';
}

sub get_name {
	my ($class) = @_;

	return 'sent_mail_log';
}

1;