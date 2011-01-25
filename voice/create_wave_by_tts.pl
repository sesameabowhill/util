#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use File::Temp qw( tempfile );
use Digest::MD5 qw( md5_hex );
use HTTP::Headers;
use HTTP::Request;
use LWP::UserAgent;
use MIME::Base64;
use URI::Escape;

my $MAX_SOX_FILES = 32;
my $MAX_FILENAME_LENGTH = 100;

# SELECT PKey, IVal, SVal FROM properties WHERE PKey IN ('Voice.VoiceID', 'Voice.TTSrate') ORDER BY PKey;

{
	my (@texts) = @ARGV;

	if (@texts) {
		my @numbers = grep {m/^[0-9]\d*$/} @texts;
		if (@numbers == @texts) {
			for my $queue_id (@numbers) {
				print "get tts for [$queue_id]\n";
				my $tts = get_tts($queue_id);
				my $bytes = remove_empty_labels( get_bytes($tts) );
				my $sound_fragments = download_sound_fragments($bytes);
				my $output_file = "_message_$queue_id.wav";
				print "write result [$output_file]\n";
				concat_sound_files($sound_fragments, $output_file);
			}
		}
		else {
			my $text = join(' ', @texts);
			my $bytes = get_bytes($text);
			my $sound_fragments = download_sound_fragments($bytes);
			my $output_file = '_message.wav';
			print "write result [$output_file]\n";
			concat_sound_files($sound_fragments, $output_file);
		}
	}
	else {
		print "Usage: $0 <text|queue_id> [queue_id...]\n";
		exit(1);
	}

}

sub remove_empty_labels {
	my ($bytes) = @_;

	my $prev_label = 1;
	my @result;
	for my $byte (reverse @$bytes) {
		if ($byte->{'type'} eq 'command') {
			if ($byte->{'name'} eq 'Label') {
				if ($prev_label) {
					## skip empty label
				}
				else {
					push(@result, $byte);
					$prev_label = 1;
				}
			}
			else {
				## skip other commands
			}
		}
		else {
			push(@result, $byte);
			$prev_label = 0;
		}
	}
	return [ reverse @result ];
}

sub download_sound_fragments {
	my ($bytes) = @_;

	my @sound_files;
	for my $byte (@$bytes) {
		my $sound_file_name;
		if ($byte->{'type'} eq 'sound') {
			print "get sound file [".$byte->{'value'}."]\n";
			my $sound_file_name = download_sound_fragment( $byte->{'value'} );
			push( @sound_files, $sound_file_name);
		}
		elsif ($byte->{'type'} eq 'text') {
			my $text = $byte->{'value'};
			$text =~ s/\s+/ /g;
			print "get text sound [$text]\n";
			my $sound_file_name = download_text_fragment($text);
			push( @sound_files, $sound_file_name);
		}
		elsif ($byte->{'type'} eq 'command') {
			if ($byte->{'name'} eq 'Label') {
				my $text = "<break time='1s' />label<break strength='weak' />".$byte->{'params'};
				print "get label text sound [$text]\n";
				my $sound_file_name = download_text_fragment($text);
				push( @sound_files, $sound_file_name);
			}
			else {
				## skip other commands
			}
		}
		else {
			die "unknown type [".$byte->{'type'}."]";
		}
	}
	return \@sound_files;
}

sub concat_sound_files {
	my ($files, $out_file) = @_;

	my @all_files = @$files;

	while (@all_files > $MAX_SOX_FILES) {
		my (undef, $temp_file) = tempfile('UNLINK' => 1, 'SUFFIX' => '.wav');
		my @first_files = splice(@all_files, 0, $MAX_SOX_FILES);
		concat_sound_files(\@first_files, $temp_file);
		unshift(@all_files, $temp_file);
	}
	my @cmd = ('sox', @all_files, $out_file);
	#print "cmd [$cmd]\n";
	system(@cmd);
}

sub make_cache_file_name {
	my ($text) = @_;

	my $cache_file = '_cache.'.uri_escape($text, "^A-Za-z0-9\-_.~()");
	$cache_file =~ s/\s/_/g;
	$cache_file =~ s/%//g;
	if (length $cache_file > $MAX_FILENAME_LENGTH) {
		my $fn_checksum = md5_hex($cache_file);
		$cache_file = substr($cache_file, 0, $MAX_FILENAME_LENGTH - 32).$fn_checksum;
	}
	return $cache_file.'.wav';
}

sub download_sound_fragment {
	my ($sound_file) = @_;

	my $cache_file = make_cache_file_name($sound_file);

	if (-e $cache_file) {
		## no need to download it
	}
	else {
		my $xml_data = make_service_request(
			'http://ws.cdyne.com/NotifyWS/GetSoundFileInUlaw',
			<<XML,
<GetSoundFileInUlaw xmlns="http://ws.cdyne.com/NotifyWS/">
  <SoundFileID>$sound_file</SoundFileID>
  <LicenseKey></LicenseKey>
</GetSoundFileInUlaw>
XML
		);
		my ( $base64_data ) = ( $xml_data =~ m#<GetSoundFileInUlawResult>(.*?)</GetSoundFileInUlawResult>#s );
		unless (defined $base64_data) {
			die "can't download [$sound_file] sound file";
		}
		my $data = decode_base64($base64_data);
		write_file($cache_file, $data);
	}
	return $cache_file;
}

sub download_text_fragment {
	my ($text) = @_;

	my $cache_file = make_cache_file_name($text);

	## fix autofills
	$text =~ s/_/ /g;

	if (-e $cache_file) {
		## no need to download it
	}
	else {
		my $xml_data = make_service_request(
			'http://ws.cdyne.com/NotifyWS/GetTTSInULAW',
			<<XML,
<GetTTSInULAW xmlns="http://ws.cdyne.com/NotifyWS/">
  <TextToSay><![CDATA[$text]]></TextToSay>
  <VoiceID></VoiceID>
  <TTSrate></TTSrate>
  <TTSvolume></TTSvolume>
  <LicenseKey></LicenseKey>
</GetTTSInULAW>
XML
		);
		my ( $base64_data ) = ( $xml_data =~ m#<GetTTSInULAWResult>(.*?)</GetTTSInULAWResult>#s );
		my $data = decode_base64($base64_data);
		write_file($cache_file, $data);
	}
	return $cache_file;
}

sub get_tts {
	my ($queue_id) = @_;

	my $xml_data = make_service_request(
		'http://ws.cdyne.com/NotifyWS/GetQueueIDStatusWithAdvancedInfo',
		<<XML,
<GetQueueIDStatusWithAdvancedInfo xmlns="http://ws.cdyne.com/NotifyWS/">
  <QueueID>$queue_id</QueueID>
  <LicenseKey></LicenseKey>
</GetQueueIDStatusWithAdvancedInfo>
XML
	);
	if ($xml_data =~ m{<TextToSay>(.*?)</TextToSay>}s) {
		return $1;
	}
	else {
		die "can't find TextToSay in [$xml_data]";
	}
}

sub write_file {
	my ($fn, $data) = @_;

	open(my $f, ">", $fn) or die "can't write [$fn]: $!";
	binmode($f);
	print $f $data;
	close($f);
}

sub read_file {
	my ($fn) = @_;

	local $/;
	open(my $f, "<", $fn) or die "can't read [$fn]: $!";
	binmode($f);
	my $data = <$f>;
	close($f);
	return $data;
}


sub get_bytes {
	my ($text) = @_;

	my $control_re = qr/~(?:\^|\\)[^~]+~/;
	my @bytes;
	my @parts = split(/($control_re)/, $text);
	for my $part (@parts) {
		if ($part =~ m/$control_re/) {
			if ($part =~ m/^~\^(.*)~$/) {
				push(
					@bytes,
					{
						'type' => 'sound',
						'value' => $1,
					}
				);
			}
			elsif ($part =~ m/^~\\(\w+)\((.*)\)~$/) {
				push(
					@bytes,
					{
						'type' => 'command',
						'name' => $1,
						'params' => $2,
					}
				);
			}
			else {
				die "wrong command [$part]";
			}
		}
		elsif ($part =~ m/\S/) {
			push(
				@bytes,
				{
					'type' => 'text',
					'value' => $part,
				}
			);
		}
		else {
			## ignore emprty parts
		}
	}
	return \@bytes;
}


sub make_service_request {
	my ($soap_action, $content) = @_;

	my $service_params = get_service_params();
	while (my ($param_key, $param_value) = each %$service_params) {
		$content =~ s{<$param_key></$param_key>}{<$param_key>$param_value</$param_key>}g;
	}

	my $request = HTTP::Request->new(
		'POST' => 'http://ws.cdyne.com/NotifyWS/PhoneNotify.asmx',
		HTTP::Headers->new(
			'Content_Type' => 'text/xml; charset=UTF-8',
			'SOAPAction'   => $soap_action,
		),
		<<XML,
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
$content
  </soap:Body>
</soap:Envelope>
XML
    );

	my $ua = LWP::UserAgent->new();
	$ua->env_proxy();

	my $response = $ua->request( $request );

	if ( $response->is_success() ) {
		return $response->content();
	}
	else {
		die "can't process request [".$request->as_string()."] responce [".$response->as_string()."]";
	}
}

sub get_service_params {
	return {
		'LicenseKey' => 'F1A49B73-1B6D-4AA9-AF9A-D41FCFA08F89',
		'VoiceID' => '1',
		'TTSrate' => '10',
		'TTSvolume' => '100',
	}
}
