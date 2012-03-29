#!/usr/bin/perl
use strict;
use warnings;

use Template;
use Image::Magick;

my ($fn) = @ARGV;
if (defined $fn) {
	my $preview = render_template($fn, {'size' => 'small'});
	my ($preview_url) = ($preview =~ m{src="([^"]+)"}i);
	my $image = render_template($fn, {'size' => 'full'});
	my ($image_url, $width, $height);
	if ($image =~ m{SWFObject\("(.*)",\s*".*",\s*"(.*)",\s*"(.*)",}i) {
		($image_url, $width, $height) = ($1, $2, $3);
	} elsif ($image =~ m{OBJECT\s+classid}i) {
		my ($embed) = ($image =~ m{<EMBED\s+(.*?)>}is);
		($image_url) = ($embed =~ m{src="([^"]+)"}i);
		($width) = ($embed =~ m{width="([^"]+)"}i);
		($height) = ($embed =~ m{height="([^"]+)"}i);
	}
	else {
		($image_url) = ($image =~ m{src="([^"]+)"}i);
		($width) = ($image =~ m{width="([^"]+)"}i);
		($height) = ($image =~ m{height="([^"]+)"}i);
	}
	if (!defined $width && $image_url =~ m{\.gif$}i) {
		($width, $height) = read_gif_size($image_url);
	}
	printf "%s,%s,%s,%s,%s\n", $fn, $image_url, $preview_url, $width, $height;
}
else {
	print "Usage $0 <tmpl>\n";
	exit(1);
}

sub render_template {
	my ($fn, $params) = @_;

	my $body;
	my $template = Template->new({'ABSOLUTE' => 1, 'RELATIVE' => 1});
	$template->process($fn, $params, \$body) or die $template->error();
	return $body;
}

sub read_gif_size {
	my ($fn) = @_;

	my $img = Image::Magick->new();
	$img->Read($ENV{SESAME_COMMON}.$fn);
	return $img->Get('width', 'height');
}
