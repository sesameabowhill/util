#!/usr/bin/perl
## $Id: resurect_all_clinchecks.pl 3292 2010-08-24 21:41:53Z ivan $

use strict;
use warnings;

use File::Spec;
use File::Find;

use lib '../lib';

use Logger;

my ($folder, $max_files_in_group) = @ARGV;
if (defined $max_files_in_group && $max_files_in_group > 0) {
	my $logger = Logger->new();
	my $start_time = time();
	my $adf_files = find_adf_files($logger, $folder);
	my $grouped_files = make_smaller_groups_by_part($logger, $adf_files, $max_files_in_group);
	my $commands = generate_shell_commands($logger, $grouped_files);
	my $fn = "_move_adf_files.sh";
	$logger->printf("save shell commands to [$fn]");
	$logger->save_commands_to_file($fn);
	$logger->print_category_stat();
	my $work_time = time() - $start_time;
	printf "done in %d:%02d\n", $work_time / 60, $work_time % 60;
}
else {
	print "Usage: $0 <folder> <max_files_in_group>\n";
	exit(1);
}

sub generate_shell_commands {
	my ($logger, $grouped_files) = @_;

	my %not_copy_part;
	for my $group (@$grouped_files) {
		my $processed_part = $group->[0]{'processed_part'};
		if (exists $not_copy_part{$processed_part}) {
			my $to_folder_name = $group->[0]{'date_folder'}."_".$not_copy_part{$processed_part}++;
			my $commands = commands_to_move($logger, $group, $to_folder_name);
			$logger->printf_slow("new folder [%s]", $to_folder_name);
			$logger->register_category("new folders");
		}
		else {
			$not_copy_part{$processed_part} = 1;
		}
	}
}

sub commands_to_move {
	my ($logger, $files, $to_folder) = @_;

	my $to_folder_path = File::Spec->join(
		$files->[0]{'base_folder'},
		$to_folder,
		$files->[0]{'client_id'}
	);
	$logger->add_command(
		sprintf(
			'mkdir -p "%s"',
			$to_folder_path,
		)
	);
	for my $file (@$files){
		$logger->add_command(
			sprintf(
				'mv "%s" "%s"',
				File::Spec->join($file->{'base_folder'}, $file->{'date_folder'}, $file->{'relative_name'}),
				$to_folder_path,
			)
		);
		$logger->register_category("files to move");
	}
}

sub make_smaller_groups_by_part {
	my ($logger, $adf_files, $max_files_in_group) = @_;

	my %files_by_part;
	for my $file (@$adf_files) {
		push(
			@{ $files_by_part{ $file->{'processed_part'} } },
			$file
		);
	}
	my @small_groups;
	## find parts with large amount of files
	for my $group (values %files_by_part) {
		if (@$group > $max_files_in_group) {
			$logger->register_category("large folders");
			my $splited_group = split_group($group, $max_files_in_group);
			push(@small_groups, @$splited_group);
			$logger->printf(
				"folder [%s] with [%d] files splited into [%d] folders",
				$group->[0]{'processed_part'},
				scalar @$group,
				scalar @$splited_group,
			);
		}
		else {
			$logger->register_category("small folders");
			push(@small_groups, $group);
		}
	}
	return \@small_groups;
}

sub split_group {
	my ($group, $max_files_in_group) = @_;

	my @group_parts;
	my @group = @$group; ## make copy
	while(@group > $max_files_in_group) {
		push(
			@group_parts,
			[ splice(@group, 0, $max_files_in_group) ],
		);
	}
	if (@group) {
		push(@group_parts, \@group);
	}
	return \@group_parts;
}

sub find_adf_files {
	my ($logger, $folder) = @_;

	my @adf_files;
	find(
		{
			'wanted' => sub {
				if (-f && m/\.adf$/) {
					my $file_name = $_;
					$logger->printf_slow("adf file [%s]", $file_name);
					$logger->register_category("total files");
					my (@dirs) = File::Spec->splitdir($file_name);
					my $file = pop @dirs;
					my $patient_folder = pop @dirs;
					my $client_id = pop @dirs;
					my $date_folder = pop @dirs;
					push(
						@adf_files,
						{
							'file_name' => $file_name,
							'date_folder' => $date_folder,
							'base_folder' => File::Spec->join(@dirs),
							'processed_part' => File::Spec->join($date_folder, $client_id),
							'relative_name' => File::Spec->join($client_id, $patient_folder),
							'client_id' => $client_id,
						}
					);
				}
			},
			'no_chdir' => 1,
		},
		$folder
	);
	return \@adf_files;
}