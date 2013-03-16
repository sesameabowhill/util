#!/usr/bin/perl

use strict;
use warnings;

use Net::Amazon::EC2;
use CGI;
use List::Util 'sum';

use constant 'TAG_NAME' => 'test-instance-for';

{
	my $ec2 = Net::Amazon::EC2->new(
		'AWSAccessKeyId' => $ENV{'AWSAccessKeyId'},
		'SecretAccessKey' => $ENV{'SecretAccessKey'},
	);

	my $instances = get_extractor_instances($ec2);
	my %known_instance_ids = map { $_->{'instance_id'} => $_->{'instance_id'} } @$instances;

	my $cgi = CGI->new();
	my $action = $cgi->param('action') // '';
	my $instance_id = $known_instance_ids{ $cgi->param('instance_id') // '' };
	if ($action eq 'start' && defined $instance_id) {
		$ec2->start_instances( 'InstanceId' => $instance_id );
		print $cgi->redirect("?".time());
		exit(0);
	}

	if ($action eq 'stop' && defined $instance_id) {
		$ec2->stop_instances( 'InstanceId' => $instance_id );
		print $cgi->redirect("?".time());
		exit(0);
	}

	if ($action eq 'comment' && defined $instance_id) {
		update_comment($ec2, $instance_id, (scalar $cgi->param('comment') || ""));
		print $cgi->redirect("?".time());
		exit(0);
	}

	my $sort = $cgi->param('sort') // 'comment';

	print $cgi->header();
	print <<HTML;
<html>
	<head>
		<title>Test AWS instances</title>
		<script>
function update_comment(instance_id) {
	var comment = document.getElementById('comment_' + instance_id);
	var new_comment = window.prompt('Instance ' + instance_id + ' is used for:', comment.value);
	if (new_comment != null) {
		comment.value = new_comment;
		comment.form.submit();
	}
}
		</script>
		<style>
body { font-family: Arial, Verdana, Helvetica; }
table {border-collapse: collapse; border: 1px #000 solid}
h2 {font-size: 14pt}
td, th {border-bottom:  1px #000 solid; padding: 0.2em 0.5em; border-left: 1px #000 dashed}
th {color: #999; font-weight: normal;}
.number {text-align: right;}
th a {color: #000;}
.sort {background-color: #eee;}
.running {background-color: #C9FFCF;}
.price {color: #bbb; font-size: 9pt;}
.state {font-style: italic; font-size: 11pt;}
.action {font-style: italic; text-align: center;}
.platform {font-size: 11pt;}
.comment {font-weight: bolder; float: left;}
.update-comment {float: right; margin-left: 1em}
form {margin: 0; display: inline;}
		</style>
	</head>
	<body>
HTML

	if (@$instances) {
		print <<HTML;
		<h2>Test instances<h2>
		<table>
HTML
		print "<tr>";
		print "<th>#</th>";
		print "<th>Instance Id</th>";
		print "<th>Platform</th>";
		print "<th>Public Ip</th>";
		print "<th>EBS size</th>";
		print "<th".($sort eq 'comment' ? " class='sort'" : "")."><a href='?sort=comment'>Description</a></th>";
		print "<th".($sort eq 'state' ? " class='sort'" : "")."><a href='?sort=state'>State</a></th>";
		print "<th>Price</th>";
		print "<th>Action</th>";
		print "</tr>";

		my $count = 1;
		my $refresh = 0;
		if ($sort eq 'state') {
			$instances = [ sort {$a->{'instance_state'} cmp $b->{'instance_state'} || !! length $b->{'comment'} <=> !! length $a->{'comment'} || $a->{'comment'} cmp $b->{'comment'}}  @$instances ]
		} else {
			$instances = [ sort {!! length $b->{'comment'} <=> !! length $a->{'comment'} || $a->{'comment'} cmp $b->{'comment'}}  @$instances ]
		}
		my $total_cost = 0;
		my $total_ebs_size = 0;
		for my $instance (@$instances) {

			print "<tr class='".$instance->{'instance_state'}."'>";
			print "<td class='number'>".$count++."</td>";
			print "<td title='".$instance->{'name'}."'>".$instance->{'instance_id'}."</td>";
			print "<td class='platform'>".$instance->{'platform'}."</td>";
			print "<td>".$instance->{'public_ip'}."</td>";
			print "<td class='number'>".$instance->{'total_volume_size'}." GB</td>";
			print "<td>";
			print "<div class='comment'>".$instance->{'comment'}."</div>";
			print "<div class='update-comment'><form class='edit' method='post'><input type='hidden' name='action' value='comment'>";
			print "<input type='hidden' name='instance_id' value='".$instance->{'instance_id'}."'>";
			print "<input type='hidden' name='comment' value='".$instance->{'comment'}."' id='comment_".$instance->{'instance_id'}."'>";
			print "[<a href='javascript: void(0)' onclick=\"update_comment('".$instance->{'instance_id'}."')\">edit</a>]</form></div>";
			print "</td>";
			print "<td class='state'>".$instance->{'instance_state'}."</td>";
			my ($comment, $price) = get_price_per_instance($instance);
			if (defined $price) {
				$total_cost += $price;
			}
			$total_ebs_size += $instance->{'total_volume_size'};
			print "<td class='price'>".(defined $price && $price ? 
				sprintf("<span title='%s'>\$%.3f</span>", $comment, $price / 1000) : 
				"<div class='action'>&mdash;</div>")."</td>";
			print "<td class='action'>";
			if ($instance->{'instance_state'} eq 'running') {
				print_button('stop', $instance->{'instance_id'});
			} elsif ($instance->{'instance_state'} eq 'stopped') {
				print_button('start', $instance->{'instance_id'});
			} elsif ($instance->{'instance_state'} eq 'pending' || 
				$instance->{'instance_state'} eq 'shutting-down' || 
				$instance->{'instance_state'} eq 'stopping'
			) {
				$refresh = 1;
				print "<img src='https://dgxo74y2ggvh1.cloudfront.net/progress.gif'>";
			} else {
				print "&nbsp;";
			}
			print "</td>";
			print "</tr>\n";
		}

		if ($refresh) {
			print "<script>window.setTimeout(function(){window.location='?".time()."';}, 30000)</script>";
		}
		
		print <<HTML;
		</table>
HTML
		print "<p class='price'>";
		my $ec2_cost_month = $total_cost * 24*30;
		my $ebs_cost = $total_ebs_size * 100;
		printf "Estimated EC2 instances cost: \$%.3f per hour (\$%.2f per month)</br>", $total_cost / 1000, $ec2_cost_month / 1000;
		printf "Estimated EBS volumes cost: \$%.2f per month (%d GB)</br>", $ebs_cost / 1000, $total_ebs_size;
		printf "Estimated total cost: \$%.3f per month</br>", ($ebs_cost + $ec2_cost_month) / 1000;
		print "</p>";

	} else {
		print "<h2>No test instances found</h2>";
	}

	print <<HTML;
	</body>
</html>
HTML

}

sub get_price_per_instance {
    my ($instance) = @_;

    my %prices = (
    	'windows' => {
	    	'm1.large' => 460,
	    	'm1.medium' => 230,
	    	'm1.small' => 115,
	    	't1.micro' => 20,
	    	'm3.xlarge' => 980,
    	},
    	'' => {
	    	'm1.large' => 240,
	    	'm1.medium' => 120,
	    	'm1.small' => 60,
	    	't1.micro' => 20,
	    	'm3.xlarge' => 500,
    	}
	);
	
	if ($instance->{'instance_state'} eq 'running') {
		my $platform = $instance->{'platform'} // '';
		if (exists $prices{$platform}{$instance->{'instance_type'}}) {
			return ($instance->{'instance_type'}, $prices{$platform}{$instance->{'instance_type'}});
		} else {
			return ('unknown', undef);
		}
	} elsif ($instance->{'instance_state'} eq 'stopped') {
		if (defined $instance->{'public_ip'}) {
			return ('public ip', 5);
		} else {
			return ('no cost', 0);
		}
	}
}

sub print_button {
    my ($action, $instance_id) = @_;
	
	print "<form method='post'><input type='hidden' name='action' value='".$action."'>";
	print "<input type='hidden' name='instance_id' value='".$instance_id."'><button type='submit'>".$action."</button></form>";
}

sub get_extractor_instances {
    my ($ec2) = @_;

	my %public_ips;
	for my $address (@{ $ec2->describe_addresses() }) {
		if (defined $address->instance_id) {
			$public_ips{$address->instance_id} = $address->public_ip;
		}
	}

	my @instances;
	my @volume_ids;
	my $instances = $ec2->describe_instances('Filter' => [ 'tag-key' => TAG_NAME ]);
	for my $reservation (@$instances) {
		for my $instance (@{ $reservation->instances_set }) {
			my $tags = $instance->tag_set;
			my @comment = map { $_->value } grep { $_->key eq TAG_NAME } @$tags;
			my @name = map { $_->value } grep { $_->key eq 'Name' } @$tags;

			my @attached_volume_ids = grep { defined } map { $_->ebs->volume_id } @{ $instance->block_device_mapping };
			push(@volume_ids, @attached_volume_ids);
			push(
				@instances,
				{
					'instance_id' => $instance->instance_id,
					'comment' => $comment[0],
					'name' => $name[0],
					'platform' => $instance->platform,
					'public_ip' => $public_ips{$instance->instance_id},
					'instance_state' => $instance->instance_state->name,
					'instance_type' => $instance->instance_type,
					'volume_ids' => \@attached_volume_ids,
				}
			);
		}
	}
	my $volumes = $ec2->describe_volumes('VolumeId' => \@volume_ids);
	my %volume_sizes = map { $_->volume_id => $_->size } @$volumes;
	for my $instance (@instances) {
		$instance->{'total_volume_size'} = sum( map { $volume_sizes{$_} } @{ $instance->{'volume_ids'} } );
	}

	return \@instances;
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
		    $ec2->create_tags(
		    	'ResourceId' => $instance_id, 
		    	'Tags' => \%tags,
			);
		}
	}

}