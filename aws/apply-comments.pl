#!/usr/bin/perl

use strict;
use warnings;

use Net::Amazon::EC2;
use CGI;

use constant 'TAG_NAME' => 'test-instance-for';

{
	my $ec2 = Net::Amazon::EC2->new(
		'AWSAccessKeyId' => $ENV{'AWSAccessKeyId'},
		'SecretAccessKey' => $ENV{'SecretAccessKey'},
	);

	my %comments = (
		'107.23.21.74'    => 'extractor alovrovich (642)',
		'107.23.86.140'   => 'extractor mwalker (2300)',
		'107.23.103.160'  => 'extractor doppel (727)',
		'107.23.103.164'  => 'extractor taker (1002)',
		'107.23.103.162'  => 'extractor linakimdds (1011)',
		'107.23.103.159'  => 'extractor cederbaum2 (500)',
		'107.23.103.163'  => 'extractor drjoondeph  (850)',
		'107.23.86.62'    => 'extractor scarstensen (777)',
		'107.21.5.1'  => 'extractor ehrmantrout (1957)',
		'107.23.58.123'   => 'extractor lovrovich2 (647)',
		'107.23.103.165'   => 'extractor brcohanim (638)',
		'107.23.103.38'   => 'extractor bbergh (359)',
		'107.23.107.225'  => 'extractor dxloew (1191)',
		'107.23.107.205' => 'extractor paubin (652)',
		'107.23.7.11'  => 'extractor bflowe (1359)',
		'107.23.107.97' => 'extractor bbratton (1065)',
		'107.21.38.127' => 'extractor dkosiorek (1479)',
		'107.23.107.200' => 'extractor msparker (1417)',
		'107.23.78.207'   => 'extractor ramcfarland (1827)',
		'107.23.103.19'  => 'extractor dcederbaum (995)',
	);

	my %public_ips;
	for my $address (@{ $ec2->describe_addresses() }) {
		if (defined $address->instance_id) {
			$public_ips{$address->public_ip} = $address->instance_id;
		}
	}
	while (my ($ip, $comment) = each %comments) {
		if (exists $public_ips{$ip}) {
			update_comment($ec2, $public_ips{$ip}, $comment);
		}
	}

}

sub update_comment {
    my ($ec2, $instance_id, $comment) = @_;
	
	my $instances = $ec2->describe_instances('Filter' => [ 'instance-id' => $instance_id ]);
	for my $reservation (@$instances) {
		for my $instance (@{ $reservation->instances_set }) {
			my %tags;
			for my $tag (@{ $instance->tag_set }) {
				$tags{$tag->key} = $tag->value;
			}
			$tags{TAG_NAME.''} = $comment;
			print "instance [$instance_id] name [$tags{Name}] comment [$comment]\n";
		    $ec2->create_tags(
		    	'ResourceId' => $instance_id, 
		    	'Tags' => \%tags,
			);
		}
	}

}



