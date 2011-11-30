## $Id:$
package Repair::Banners;

use strict;
use warnings;

use base 'Repair::Base';

sub repair {
	my ($self, $client_data) = @_;

	my $banners = $client_data->get_all_srm_resources();
	my $custom_banner_id = $client_data->get_profile_value('WebAccount->BannerId');
	for my $banner (@$banners) {
		if ($banner->{'id'} eq $custom_banner_id) {
			my $file_ext = $self->guess_file_extension($client_data, $banner->{'id'});
			if (defined $file_ext) {
				$self->make_copy_commands($client_data, $banner->{'id'}, $file_ext);
			}
			else {
				$self->{'logger'}->register_category("can't find file");
				$self->{'logger'}->printf(
					"ERROR [%s]: can't find file for [%s] custom banner",
					$client_data->get_username(),
					$banner->{'id'},
				);
			}
		}
		else {
			$self->{'logger'}->register_category("non-custom banner");
		}
	}
}

sub make_copy_commands {
	my ($self, $client_data, $guid, $file_ext) = @_;

	my $existing_file = $client_data->file_path_for_srm($guid.$file_ext);
	my $copied = 0;
	for my $ext ('.', '.jpg', '.gif') {
		my $new_file = $client_data->file_path_for_srm($guid.$ext);
		if ($new_file ne $existing_file) {
			if (-e $new_file) {
				$self->{'logger'}->printf_slow(
					"SKIP [%s]: custom banner [%s] is exists",
					$client_data->get_username(),
					$new_file,
				);
			}
			else {
				$self->{'logger'}->printf_slow(
					"COPY [%s]: custom banner [%s] => [%s]",
					$client_data->get_username(),
					$existing_file,
					$new_file,
				);
				$self->{'logger'}->add_command(qq(cp "$existing_file" "$new_file"));
				$copied ++;
			}
		}
	}
	if ($copied) {
		$self->{'logger'}->register_category("copy custom banner with [".$file_ext."] extension");
	}
	else {
		$self->{'logger'}->register_category("custom banner with [".$file_ext."] extension");
	}
}

sub guess_file_extension {
	my ($self, $client_data, $guid) = @_;

	for my $ext ('.', '.jpg', '.gif') {
		if (-e $client_data->file_path_for_srm($guid.$ext)) {
			return $ext;
		}
	}
	return undef;
}

sub get_commands_extension {
	my ($self) = @_;

	return ".sh";
}

1;