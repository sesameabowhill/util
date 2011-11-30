## $Id$

use strict;
use warnings;

use DBI;

use Sesame::Config;
use Sesame::Unified::Client;
use Sesame::Constants qw( :config );

if (@ARGV) {
	my $core_config = Sesame::Config->read_file(CONFIG_FILE_SESAME_CORE);

	my @url_map = (
		[ qr"^\Qhttp://www.sesamecommunications.com/images",      'https://'.$core_config->{'web_server_host'}.'/img/standard' ],
		[ qr"^\Qhttp://www.sesamecommunications.com/PPNarticles", 'https://'.$core_config->{'web_server_host'}.'/img/standard' ],
		[ qr"^http://[^/]+/img/standard", 'https://'.$core_config->{'web_server_host'}.'/img/standard' ],
	);

	my $dbi = get_connection(
		'email_messaging',
		$core_config->{'database_access'}{'user'},
		$core_config->{'database_access'}{'password'},
	);
	my $client_db = shift @ARGV;

	my $client = Sesame::Unified::Client->new('db_name', $client_db);
	my $emails = get_standard_emails($dbi, $client->get_id());
	my %replaced_files;
	for my $em (@$emails) {
		print "process email [$em->{subject}] is_enabled [$em->{is_enabled}]\n";
		my $need_save = 0;
		$em->{body} =~ s{(src=["'])(https?://.+?)(["'])}{
			my ($start_str, $url, $end_str) = ($1, $2, $3);
			my $start_url = $url;
			for my $elem (@url_map) {
				my ($find, $replace) = @$elem;
				if ($url =~ s/$find/$replace/) {
					if ($start_url ne $url) {
						print "replace [$start_url] with [$url]\n";
						$need_save = 1;
						$replaced_files{$start_url} = $url;
						last;
					}
				}
			}
			if ($start_url eq $url) {
				print "no changes in [$url]\n";
			}
			$start_str.$url.$end_str;
		}ge;
		if ($need_save) {
			print "save [$em->{id}]\n";
			set_message_body($dbi, $em->{id}, $em->{body});
		}
	}
	if (keys %replaced_files) {
		print "copy files:\n";
		for my $fn (sort keys %replaced_files) {
			print "$fn -> $replaced_files{$fn}\n";
		}
	}
} else {
	print "Usage: $0 <client_db>\n";
	exit(1);
}

sub replace_url {
	my ($url) = @_;

	print "url: $url\n";
	return $url;
}

sub get_standard_emails {
	my ($dbi, $client_id) = @_;

	return $dbi->selectall_arrayref(
		<<SQL, { 'Slice' => {} }, $client_id
SELECT id, subject, body, is_enabled
FROM reminder_settings
WHERE type='standard' AND client_id=?
SQL
	);
}

sub set_message_body {
	my ($dbi, $id, $body) = @_;

	$dbi->do(
		"UPDATE reminder_settings SET body=? WHERE id=?",
		undef,
		$body,
		$id,
	);
}

sub get_connection {
    my ($db_name, $db_user, $db_password) = @_;

    $db_name ||= '';

    return DBI->connect(
		"DBI:mysql:host=$ENV{SESAME_DB_SERVER}".($db_name?";database=$db_name":""),
		$db_user,
		$db_password,
		{
			RaiseError => 1,
			ShowErrorStatement => 1,
			PrintError => 0,
		}
    );
}
