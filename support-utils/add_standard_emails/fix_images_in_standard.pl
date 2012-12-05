#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib';

use Script;

Script->simple_client_loop(
	\@ARGV,
	{
		'read_only' => 1,
		'client_data_handler' => \&fix_image_src,
		'save_sql_to_file' => '_update_email_reminder_settings.%s.sql',
	}
);

sub fix_image_src {
    my ($logger, $client_data) = @_;

    my %known_guids = (
		'101028D8-4CF4-1016-9E4E-B442F29A2506' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/banner/confirm-button.gif',
		'17EA6E34-63B4-11DD-8AEB-7F3E83AD103F' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/luminners.jpg',
		'CC892680-A6D4-11DB-B88C-1973DBDC096D' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/luminners.jpg',
		'2CC35776-63B4-11DD-AEC7-423F83AD103F' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/zoom.jpg',
		'94315A98-A6CD-11DB-81FE-656ADBDC096D' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/zoom.jpg',
		'687CF61A-A6CC-11DB-A3CC-1469DBDC096D' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/brite-smile.jpg',
		'B69F7CE6-63B3-11DD-97C0-483B83AD103F' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/brite-smile.jpg',
		'D7485446-3BA8-4EE2-AEAA-CB067A730F09' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/invisalign-teens.png',
		'958EC030-A6CB-11DB-AB0C-2868DBDC096D' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/cerec.jpg',
		'E822AEF0-63B3-11DD-9F46-553D83AD103F' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/cerec.jpg',
		'ECD7B108-7ADE-11DB-9B1A-6108E3AFA3A8' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/inivsalign-open-house.gif',
		'8CBF4F6C-A6D3-11DB-B00D-9371DBDC096D' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/inivsalign-open-house.jpg',
		'FB6668B2-63B3-11DD-9AF6-013E83AD103F' => 'https://dpy8nsjf32jim.cloudfront.net/img/email/logo/inivsalign-open-house.jpg',
	);
	my $replace = join('|', map {quotemeta} keys %known_guids);
	$replace = qr/\bsrc=["'][^"']*($replace)[^"']*["']/;
	
    for my $setting (@{ $client_data->get_email_reminder_settings() }) {
    	(my $new_body = $setting->{'body'}) =~ s/$replace/'src="'.$known_guids{$1}.'"'/egi;
    	if ($new_body ne $setting->{'body'}) {
    		$client_data->update_email_reminder_setting_body($setting->{'id'}, $new_body, $setting->{'subject'});
    		$logger->register_category("changed in ".$setting->{'type'});
		} else {
    		$logger->register_category("no image found");
		}
    }
}