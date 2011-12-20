use strict;
use warnings;

use Template;

my ($fn) = @ARGV;
if (defined $fn) {
	my $preview = render_template($fn, {'size' => 'small'});
	my ($preview_url) = ($preview =~ m{src="([^"]+)"}i);
	my $image = render_template($fn, {'size' => 'full'});
	my ($image_url, $width, $height);
	if ($image =~ m{OBJECT\s+classid}i) {
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
