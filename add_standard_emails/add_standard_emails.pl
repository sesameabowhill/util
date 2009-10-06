## $Id$

use strict;
use warnings;

use DBI;
use File::Spec;
use URI::Escape;

use Sesame::Config;
use Sesame::Constants qw( :config );
use Sesame::Unified::Client;
use Sesame::Unified::ClientProperties;
use Sesame::Unified::DB;

if (@ARGV) {
	my $core_config = Sesame::Config->read_file(CONFIG_FILE_SESAME_CORE);

	my $dbi = get_connection(
		'email_messaging',
		$core_config->{'database_access'}{'user'},
		$core_config->{'database_access'}{'password'},
	);
	my $client_db = shift @ARGV;

	my $client = Sesame::Unified::Client->new('db_name', $client_db);
	my $client_dbi = Sesame::Unified::DB->get_client_db_connection($client);
	my $client_profile = Sesame::Unified::ClientProperties->new(
		$client->get_client_type(),
		$client_dbi,
	);
	my $emails = get_standard_emails($dbi, $client->get_id());
	my $default_email = $emails->[0];
	unless ($default_email) {
		die "there should be at least 1 standard email";
	}
	print "get default parameters from [$default_email->{subject}]\n";

	my %email_by_subject = map {$_->{'subject'} => $_} @$emails;

	my $new_image_guid = $client_profile->get_property('WebAccount->BannerId');
	my $new_is_enabled = 1;
	my $new_response_options = 'login,map,refer,office_address';
	my $new_design_id = 4;
	my $new_messages = read_messages( 'emails' );
	print "going to add [".@$new_messages."] emails\n";
	for my $message (@$new_messages) {
		my $currect_email;
		if (exists $email_by_subject{ $message->{'subject'} }) {
			$currect_email =  $email_by_subject{ $message->{'subject'} };
			if ($message->{'body'} eq $currect_email->{'body'}) {
				print "already added [$message->{subject}]\n";
			} else {
				print "change body for [$message->{subject}]\n";
				set_message_body($dbi, $currect_email->{'id'}, $message->{'body'});
			}
		} else {
			print "add new email [$message->{subject}]\n";
			$default_email->{'subject'} = $message->{'subject'};
			$default_email->{'body'}    = $message->{'body'};
			my $message_id = add_new_email($dbi, $default_email);
			%$currect_email = %$default_email;
			$currect_email->{'id'} = $message_id;
		}
		if ($currect_email->{'is_enabled'} ne $new_is_enabled) {
			set_message_is_enabled($dbi, $currect_email->{'id'}, $new_is_enabled);
			print "set is_enabled [$new_is_enabled] for [$message->{subject}]\n";
		}
		if ($currect_email->{'response_options'} ne $new_response_options) {
			set_message_response_options($dbi, $currect_email->{'id'}, $new_response_options);
			print "set response_options [$new_response_options] for [$message->{subject}]\n";
		}
		if ($currect_email->{'design_id'} ne $new_design_id) {
			set_message_design_id($dbi, $currect_email->{'id'}, $new_design_id);
			print "set design_id [$new_design_id] for [$message->{subject}]\n";
		}
		if ($currect_email->{'image_guid'} ne $new_image_guid) {
			set_message_image(
				$dbi,
				$currect_email->{'id'},
				$new_image_guid,
				'',
			);
			print "set image_guid [$new_image_guid] for [$message->{subject}]\n";
		}
	}
	print "done\n";
} else {
	print "Usage: $0 <client_db>\n";
	exit(1);
}

sub read_messages {
	my ($folder) = @_;

	opendir(DIR, $folder) or die "can't opendir [$folder]: $!";
    my @files = grep { -f $_->[1] } map { [ $_, File::Spec->join($folder, $_) ] } readdir(DIR);
    closedir(DIR);

	local $/;
	my @messages;
	for my $f (@files) {
		my $fn = $f->[1];
		open(my $handler, "<", $fn) or die "can't read [$fn]: $!";
		binmode($handler);
		push(
			@messages,
			{
				'subject' => unescape_filename($f->[0]),
				'body' => <$handler>,
			}
		);
		close($handler);
	}
	return \@messages;
}

sub unescape_filename {
	my ($fn) = @_;

	$fn = uri_unescape($fn);
	$fn =~ s/\.html?$//;
	$fn =~ s/\+/ /g;
	return $fn;
}

sub get_standard_emails {
	my ($dbi, $client_id) = @_;

	return $dbi->selectall_arrayref(
		<<SQL, { 'Slice' => {} }, $client_id
SELECT
	id, subject, body, is_enabled, response_options, design_id,
	image_guid, image_title, type, client_id
FROM reminder_settings
WHERE type='standard' AND client_id=?
SQL
	);
}

sub add_new_email {
	my ($dbi, $params) = @_;

	$dbi->do(
		<<SQL,
INSERT INTO reminder_settings
	(client_id, is_enabled, type, subject, body,
	response_options, design_id, image_guid, image_title )
VALUES (?,?,?, ?,?,?, ?,?,?)
SQL
		undef,
		@$params{
			'client_id', 'is_enabled', 'type', 'subject', 'body',
			'response_options', 'design_id', 'image_guid', 'image_title'
		}
	);
	return $dbi->{'mysql_insertid'};
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

sub set_message_image {
	my ($dbi, $id, $image_guid, $image_title) = @_;

	$dbi->do(
		"UPDATE reminder_settings SET image_guid=?, image_title=? WHERE id=?",
		undef,
		$image_guid,
		$image_title,
		$id,
	);
}

sub set_message_is_enabled {
	my ($dbi, $id, $is_enabled) = @_;

	$dbi->do(
		"UPDATE reminder_settings SET is_enabled=? WHERE id=?",
		undef,
		$is_enabled,
		$id,
	);
}

sub set_message_response_options {
	my ($dbi, $id, $response_options) = @_;

	$dbi->do(
		"UPDATE reminder_settings SET response_options=? WHERE id=?",
		undef,
		$response_options,
		$id,
	);
}

sub set_message_design_id {
	my ($dbi, $id, $design_id) = @_;

	$dbi->do(
		"UPDATE reminder_settings SET design_id=? WHERE id=?",
		undef,
		$design_id,
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
