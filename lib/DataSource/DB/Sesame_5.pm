## $Id$
package DataSource::DB::Sesame_5;

use strict;
use warnings;

use File::Spec;
use IPC::Run3;

#use Sesame::Unified::Client;
#use Sesame::Unified::ClientProperties;

use base qw( DataSource::DB );

sub get_client_data_by_db {
    my ($self, $db) = @_;

    require ClientData::DB::Sesame_5;
    return ClientData::DB::Sesame_5->new($self, $db, $self->{'dbh'});
}

sub get_client_data_by_id {
    my ($self, $id) = @_;

    require ClientData::DB::Sesame_5;
    return ClientData::DB::Sesame_5->new_by_id($self, $id, $self->{'dbh'});
}

sub get_client_data_for_all {
	my ($self) = @_;

    require ClientData::DB::Sesame_5;
	return [
		map { ClientData::DB::Sesame_5->new($self, $_->get_username(), $self->{'dbh'}, $_)  }
		@{ Sesame::Unified::Client->get_all_clients() }
	];
}

sub get_all_case_numbers {
	my ($self) = @_;

	return $self->{'dbh'}->selectcol_arrayref(<<'SQL');
SELECT case_number FROM invisalign_case_process_patient
UNION
SELECT case_num AS case_number FROM invisalign_patient
SQL
}

sub get_invisalign_client_ids_by_case_number {
	my ($self, $case_number) = @_;

	return $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT invisalign_client_id FROM invisalign_patient WHERE case_num=?
SQL
}

sub get_invisalign_processing_client_ids_by_case_number {
	my ($self, $case_number) = @_;

	return $self->{'dbh'}->selectcol_arrayref(<<'SQL', undef, $case_number);
SELECT invisalign_client_id FROM invisalign_case_process_patient WHERE case_number=?
SQL
}

sub get_client_id_by_invisalign_id {
	my ($self, $invisalign_id) = @_;

	return scalar $self->{'dbh'}->selectrow_array(<<'SQL', undef, $invisalign_id);
SELECT client_id FROM invisalign_client WHERE id=?
SQL
}

sub get_all_clincheck_files {
	my ($self) = @_;

	my @cmd = (
		'find',
		File::Spec->join(
	    	$ENV{'SESAME_COMMON'},
	    	'invisalign-cases',
	    ),
		'-type', 'f',
		'-name', '*.txt',
	);
	my ($output, $err);
	run3(\@cmd, \undef, \$output, \$err);
	my @files;
	for my $fn (split m/\r?\n/, $output) {
		my @file_mtime = (localtime((stat($fn))[9]))[5, 4, 3];
		$file_mtime[0] += 1900;
		$file_mtime[1] ++;
		my ($id, $file) = (File::Spec->splitdir($fn))[-2, -1];
		my $params = _read_clinchecks_settings($fn) || {};
		($params->{'case_number'} = $file) =~ s/\.txt$//;
		($params->{'file_mask'}   = $fn)   =~ s/\.txt$/*/;
		$params->{'file'} = $fn;
		$params->{'file_mtime'} = sprintf('%04d-%02d-%02d', @file_mtime);
		push(@files, $params);
	}
	return \@files;
}

sub _read_clinchecks_settings {
	my ($file) = @_;

	local $/;
	open(my $f, "<", $file) or die "can't read [$file]: $!";
	my $data = <$f>;
	close($f);

	if ($data =~ m/---PTI Russia comments---(.*)---End of comments---/si) {
		my ($params_str) = ($1);
		my %params;
		for my $line (split m/\r?\n/, $params_str) {
			my ($key, $value) = split(m/:/, $line, 2);
			if (defined $key) {
				$params{$key} = $value;
			}
		}
		my @dt = split(m'/', $params{'Data'}, 3);
		$dt[2] += 2000;
		return {
			'date' => sprintf('%04d-%02d-%02d', @dt[2, 1, 0]),
			'stages' => $params{'Stages #'},
			#'case_number' => $params{'Patient Case Number'},
		};
	}
	else {
		return undef;
	}

#Patient First Name:Kelly
#Patient Last Name:Simmermaker
#Patient Case Number:1167917
#Patient ADF File Name:Kelly Simmermaker 07_30_09__13_05.adf
#Doctor ID:148
#Doctor login:rgakhal3
#Data:30/07/09
#Stages #:16

}

1;