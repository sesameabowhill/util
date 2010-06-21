#!/usr/bin/perl
## $Id: repair_data.pl 2098 2010-06-09 19:22:05Z ivan $

use strict;
use warnings;

use lib '../lib';

use DataSource::DB;
use DateUtils;

my $EXPIRE_KEY  = 'Reminder.UploadExpire';
my $EXPIRE_TYPE = 'IVal';

my ($days, @clients) = @ARGV;
if (@clients) {
	$|=1;
	my $start_time = time();
	my $data_source = DataSource::DB->new();
	@clients = @{ $data_source->expand_client_group( \@clients ) };
	for my $username (@clients) {
		my $client_data = $data_source->get_client_data_by_db($username);
		my $current_value = $client_data->get_profile_value($EXPIRE_KEY);
		if (defined $current_value) {
			if ($current_value < $days) {
				$data_source->set_read_only(0);
				$client_data->set_profile_value($EXPIRE_KEY, $days, $EXPIRE_TYPE);
				$data_source->set_read_only(1);
				$client_data->set_profile_value($EXPIRE_KEY, $current_value, $EXPIRE_TYPE);
				printf "CHANGE [".$client_data->get_username()."]: set expiration to [$days] days\n";
				$client_data->register_category('settings changed');
			}
			else {
				printf "SKIP [".$client_data->get_username()."]: current settings are not changed\n";
				$client_data->register_category('no need to change settings');
			}
		}
		else {
			printf "SKIP [".$client_data->get_username()."]: set expiration key doesn't exists\n";
			$client_data->register_category('profile key is not found');
		}
	}
	my $fn = '_expiration_setting_backup.'.DateUtils->get_current_date_filename().'.sql';
	print "write settings backup to [$fn]\n";
	$data_source->save_sql_commands_to_file($fn);
	my $stat = $data_source->get_categories_stat();
	for my $category (sort keys %$stat) {
		printf("%s - %d\n", $category, $stat->{$category});
	}
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 <days> <client_db1> ...\n";
	exit(1);
}
