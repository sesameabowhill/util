#!/usr/bin/perl
## $Id$

use strict;
use warnings;

use HTTP::Headers;
use HTTP::Request;
use LWP::UserAgent;
use MIME::Base64;

# SELECT PKey, IVal, SVal FROM properties WHERE PKey IN ('Voice.VoiceID', 'Voice.TTSrate') ORDER BY PKey;

{
	my ($first_filename) = @ARGV;

	if (defined $first_filename) {
		for my $filename (@ARGV) {
			print "processing [$filename]\n";
			my $file_data = read_file($filename);
			( my $file_id = $filename ) =~ s/\.wav$//;
			my $result = upload_file($file_data, $file_id);
			if ($result->{'success'}) {
				print "uploaded [$file_id]: duration ".$result->{'length'}." seconds\n";
			}
			else {
				print "error while uploading [$file_id]: ".$result->{'error_message'}."\n";
			}
		}
	}
	else {
		print "Usage: $0 <file_name> ...\n";
		exit(1);
	}
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

sub upload_file {
	my ($data, $id) = @_;

	$data = encode_base64($data);

	my $xml_result = make_service_request(
		"http://ws.cdyne.com/NotifyWS/UploadSoundFile",
		<<XML,
<UploadSoundFile xmlns="http://ws.cdyne.com/NotifyWS/">
  <FileBinary>$data</FileBinary>
  <SoundFileID>$id</SoundFileID>
  <LicenseKey></LicenseKey>
</UploadSoundFile>
XML
	);

	return {
		'success' => ( get_xml_param_value($xml_result, 'UploadSuccessful') eq 'true' ),
		'length' => get_xml_param_value($xml_result, 'UploadedLengthInSeconds'),
		'error_message' => get_xml_param_value($xml_result, 'ErrorResponse'),
	};
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

sub get_xml_param_value {
	my ($xml, $param) = @_;

	if ( $xml =~ m{<$param>([^<]+)</$param>} ) {
		return $1;
	}
	else {
		return undef;
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
