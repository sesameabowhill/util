#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Spec;
use Digest::SHA qw( sha1_hex );
use File::Path 'make_path';

use lib '../lib';

use Script;
use DateUtils;

my ($folder) = shift @ARGV;

Script->simple_client_loop(
	\@ARGV,
	{
		'read_only' => 1,
		'options' => '<output_folder>',
		'client_data_handler' => \&extract_sent_mail_log,
		'save_sql_to_file' => '_update_email_sent_mail_log.sql',
	}
);

sub extract_sent_mail_log {
	my ($logger, $client_data) = @_;

	my $date = DateUtils->now()->as_mysql_date();

	for my $email (@{ $client_data->get_all_sent_emails_with_body() }) {
		my $file_name = _put_message_to_file($client_data->get_username(), $folder, $date, $email->{'Body'});
		$client_data->set_sent_email_body($email->{'id'}, "file://".$file_name);
		$logger->printf_slow("save email body [$file_name]");
		$logger->register_category("body saved to file");
	}
}

sub _put_message_to_file {
	my ($username, $root_folder, $mail_date, $body) = @_;

	## generate file name the same way as git does
	my $hash = sha1_hex($body);
	my $folder = File::Spec->join(
		'sent-mail-log2',
		$username,
		$mail_date,
		substr($hash, 0, 2)
	);
	make_path(File::Spec->join($root_folder, $folder));
	my $file = File::Spec->join($folder, substr($hash, 2).".html");
	my $full_path = File::Spec->join($root_folder, $file);
	open(my $fh, ">", $full_path) or die "can't save email body [$full_path]: $!";
	binmode($fh);
	print $fh $body;
	close($fh);
	return $file;
}
