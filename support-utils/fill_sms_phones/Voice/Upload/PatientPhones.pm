## $Header: //depot/Sesame/Server Projects/Current/Sesame Voice/Src/Source/Voice/Upload/PatientPhones.pm#6 $
package Voice::Upload::PatientPhones;

use strict;
use warnings;

use Params::Validate qw( :all );
use Readonly;

use Sesame::Config;
use Sesame::Error;
use Voice::Constants qw( CONFIG_FILE_VOICE );

my %zipcodes;

Readonly my @CLIENT_TYPES      => qw/ortho dental/;
Readonly my $CDYNE_PROVIDER_ID => 100;

sub new {
	validate_pos( @_, { type => SCALAR }, { type => OBJECT }, { type => SCALAR } );
	my ($class, $client_dbh, $client_type) = @_;

	my $self;

	my $right_type_flag = 0;
	$right_type_flag += ($client_type eq $_) for @CLIENT_TYPES;
	if (!$right_type_flag) {
		die "Unknown client type: $client_type";
	} else {
		$self->{'dbh'}  = $client_dbh;
		$self->{'type'} = $client_type;

		return bless $self, $class;
	}
}

sub get_patients_zipcodes {
	validate_pos( @_, { type => OBJECT } );
	my $self = shift;
	my $dbh = $self->{'dbh'};

	my $zc;

	if ($self->{'type'} eq 'ortho') {
		$zc = $dbh->selectcol_arrayref(<<SQL);
		SELECT DISTINCT REPLACE(Zip, ' ', '') AS ZIP FROM addresses
		WHERE Zip IS NOT NULL AND length(trim(Zip))>0
SQL
	}
	elsif ($self->{'type'} eq 'dental') {
		$zc = $dbh->selectcol_arrayref(<<SQL);
		SELECT DISTINCT REPLACE(Zipcode, ' ', '') AS ZIP FROM Addresses
		WHERE Zipcode IS NOT NULL AND length(trim(Zipcode))>0
SQL
	}

	return $zc;
}

sub init_zip_codes {
	my ($self, $zc) = @_;
	%zipcodes = %$zc;
}

sub fill_phone_book {
	validate_pos( @_, { type => OBJECT }, { type => HASHREF } );
	my $self = shift;
	my $phone_data = shift;
	my $dbh = $self->{'dbh'};

	my $sth = _get_sth_patients_with_addresses($dbh, $self->{'type'});
	$sth->execute();

	my $config_ref = Sesame::Config->read_file( CONFIG_FILE_VOICE );
	my $pms_with_phone_types = $config_ref->{'pms_with_phone_types'};

	my $db_name = $dbh->selectrow_array("SELECT DATABASE()");
	my $unified_client = Sesame::Unified::Client->new('db_name',  $db_name);
	#my $client_pms = $unified_client->get_pms_id();
	#my $is_phone_types = scalar (grep {$_ eq $client_pms} @$pms_with_phone_types);

	PHONE:
	while (my $r = $sth->fetchrow_hashref()) {
		{
			my $new_phone = $phone_data->{$r->{BDate}}{$r->{FName}}{$r->{LName}};
			if (defined $new_phone) {
				print "[$new_phone] -> [".$r->{Phone}."]\n";
				$r->{Phone} = $new_phone;
			} else {
				next PHONE;
			}
		}
		
		my $all_phones = get_phones($r->{'Phone'});
		#if ($is_phone_types) {
		#	$all_phones = [grep {
		#		$_->{'comment'} eq 'cell' ||
		#		$_->{'comment'} eq 'mobile'} @$all_phones];
		#}

		if (exists($r->{'RId'})) {
			# add all phones to phone_book table
			foreach my $phone (@$all_phones) {
				if (defined $phone->{'phone'}) {
					my $phone_area = $phone->{'area'} ? $phone->{'area'}: _get_area_by_zip($r->{'ZIP'});
					_add_phone_to_phone_book($dbh, {
						'phone'  => $phone_area ? $phone_area.$phone->{'phone'} : $phone->{'phone'},
						'pid'    => $r->{'PId'},
						'rid'    => $r->{'RId'},
						'type'   => $phone->{'comment'},
						'active' => 1,
						}
					);
				}
			}
		}
		elsif (exists($r->{'SAId'})) {
			my $responsibles = _get_responsibles($dbh, $r->{'SAId'});
			foreach my $responsible (@$responsibles) {
				foreach my $phone (@$all_phones) {
					if (defined $phone->{'phone'}) {
						my $phone_area = $phone->{area} ? $phone->{area}: _get_area_by_zip($r->{ZIP});
						_add_phone_to_phone_book($dbh, {
							'phone'  => $phone_area ? $phone_area.$phone->{'phone'} : $phone->{'phone'},
							'pid'    => $r->{'PId'},
							'rid'    => $responsible->{'RId'},
							'type'   => $phone->{'comment'},
							'active' => 1,
							}
						);
					}
				}
			}
		}
	}
}

sub fill_patient_phones {
	validate_pos( @_, { type => OBJECT } );
	my $self = shift;

	my $config_ref = Sesame::Config->read_file( CONFIG_FILE_VOICE );
	my $phone_priority = $config_ref->{'phone_type_priority'};

	my $dbh = $self->{'dbh'};

	# delete all data from patient_phones table
	$dbh->do (<<SQL);
DELETE FROM patient_phones
SQL

	my $sth = _get_sth_patients_with_addresses($dbh, $self->{'type'});
	$sth->execute();

	while (my $r = $sth->fetchrow_hashref()) {
		if ($r->{'Phone'}) {
			_add_phone($dbh, get_actual_phone($r, $phone_priority));
		}
	}
}

# input: (801)525-1589 (Home); (801)578-2730dad (Work)
# output: {"phone" => 5251589, "comment" => "home", "area" => 801},
#         {"phone" => 5782730, "comment" => "work", "area" => 801}
sub get_phones {
	my $phone = shift;
	return undef if !$phone;

	my @arr_phones = split /[;,]/, $phone;

	my @result;
	foreach my $p (@arr_phones)
	{
		my $digits = undef;
		my $comment = undef;
		my ($comment1, $country, $area, $part1, $part2, $comment2, $add, $comment3) =
			($p =~ /^
					\s*
					(?:
						(\w*)\:          # sometimes description is written first
					)?
                    (?:                 # country code is unnessesary
                        \(?(\d)?\)?     # country code
						[-\s]?
                    )??
					\(?(\d{3})?\)?              # area code
					[-\s]*
					(\d{3})                     # 1st part of phone
					[-\s]*
					(\d{4})                     # 2nd part of phone
					[-\s]*
					(\w*)
					[-\s]*
					\(?(\d*)\)?                 # addiction
					[-\s]*
					[\(\[]?([\w\s]*)[\)\]]?     # phone description
					/x);
		if ( $part1 && $part2 )
		{
			$digits = $part1 . $part2;
		}
		$comment = $comment1 ? lc $comment1 : lc $comment3 || lc $comment2;
		$comment = ($comment eq "phone") ? "home" : $comment;
		$comment = "home" if ($comment =~ /home/);
		push @result,
		{
		   "area"      => ( $area && ($area !~ m/^(0+)$/) ) ? $area : undef,
		   "phone"     => ( $digits && ($digits !~ m/^(0+)$/) ) ? $digits: undef,
		   "comment"   => $comment ? $comment : "unknown",
		};

	}
	return undef if !@result;
	return \@result;
}

sub get_actual_phone {
	validate_pos( @_, { type => HASHREF }, { type => HASHREF } );
	my ($addr, $phone_priority) = @_;

	# get home phone
	my $phone = _get_actual_phone($addr->{Phone}, $phone_priority);

	return {
		'PId'       => $addr->{'PId'},
		'Phone'     => $phone->{'phone'},
		# check for area code
		'AreaCode'  => $phone->{'area'} ? $phone->{'area'}: _get_area_by_zip ($addr->{'ZIP'}),
		'Descr'     => $phone->{'comment'},
	};
}

sub _get_phone_by_type {
	validate_pos( @_, { type => ARRAYREF }, { type => SCALAR } );
	my ($parsed_phones, $phone_type) = @_;

	return ( grep { defined $_->{'comment'} && $_->{'comment'} eq $phone_type } @$parsed_phones )[0];
}

sub _get_actual_phone {
	validate_pos( @_, { type => SCALAR }, { type => HASHREF } );
	my ($phones, $phone_priority) = @_;

	my $parsed_phones = get_phones($phones);

	my @home_phone = map {
		_get_phone_by_type($parsed_phones, $phone_priority->{$_})
	} sort keys %$phone_priority;

	if (defined $home_phone[0]) {
		return $home_phone[0];
	} else {
		return $parsed_phones->[0];
	}
}

# input: 73010
# output: 405
sub _get_area_by_zip {
	my $zip = shift;
	if ($zip) {
		# trim zip to 5 digits
		$zip =~ s/\s+//g;
		$zip = substr($zip, 0, 6);
		return $zipcodes{$zip};
	} else {
		return undef;
	}
}

sub _add_phone {
	my ($dbh, $params) = @_;

# CHECK FOR OBLIGATORY PARAMS
	my $c = 0;
	my @must = ('PId', 'Phone', 'AreaCode');
	$c += (exists $params->{$_} && defined $params->{$_}) for @must;
	return 0 if $c != @must;

	# add phone
	my $sth = $dbh->prepare(<<SQL);
INSERT INTO patient_phones (PId, Phone, AreaCode, CountryCode, Registered, Description)
VALUES (?, ?, ?, '+1', sysdate(), ?)
SQL

	$sth->execute($params->{PId}, $params->{Phone},$params->{AreaCode}, $params->{Descr});
	return 1;
}

sub _add_phone_to_phone_book {
	my ($dbh, $phone) = @_;

	# if phone has not been removed by patient from PtPages
	if ( !_is_phone_removed($dbh, $phone->{'phone'}) ) {

		my %new_phone = (
			'source'       => 'sesame',
			'patient_id'   => $phone->{'pid'},
			'ACL'          => $phone->{'rid'},
			'phone_object' => {
				'Phone'          => $phone->{'phone'},
				'ProviderId'     => $CDYNE_PROVIDER_ID,
				'InvitationCode' => '',
				'MessageLimit'   => 0,
				'active'         => $phone->{'active'},
			},
		);

		_add_contact($dbh, \%new_phone);
	}

	return 1;
}

sub _is_phone_removed {
	my ($dbh, $phone) = @_;

	my $is_phone_removed = 0;

	if (defined $phone) {
		my $sth = $dbh->prepare(<<SQL);
SELECT COUNT(*) AS count FROM phone_history WHERE Phone=?
SQL

		$sth->execute($phone);
		$is_phone_removed = $sth->fetchrow_hashref()->{'count'};
	}
	return $is_phone_removed;
}

sub _get_responsibles {
	my ($dbh, $said) = @_;

	if ($said) {
		my $sth = $dbh->prepare(<<SQL);
			SELECT
				DISTINCT RId
			FROM
				prlinks
			WHERE
				SAId = ?
			ORDER BY
				RId
SQL
		$sth->execute($said);
		my $responsibles = $sth->fetchall_arrayref( {} );
		return $responsibles;
	} else {
		return;
	}
}

sub _get_sth_patients_with_addresses {
	my ($dbh, $type) = @_;
	my $sth;

	if ($type eq 'ortho') {
		$sth = $dbh->prepare(<<SQL);
	SELECT
		DISTINCT
			p.PId AS PId,
			p.Phone AS Phone,
			a.ZIP AS ZIP,
			a.Street AS Street,
			prl.SAId as SAId
	FROM
		patients AS p
		LEFT JOIN addresses a
			ON p.PId = a.PId
		LEFT JOIN prlinks prl
			ON prl.PId = p.PId
	WHERE
		p.Phone IS NOT NULL AND p.Phone != ''
	GROUP BY
		p.PId
SQL
	}
	elsif ($type eq 'dental') {
		$sth = $dbh->prepare(<<SQL);
	SELECT
		p.FName,
		p.LName,
		p.BDate,
		p.PId AS PId,
		p.Rid AS RId,
		p.Phone AS Phone,
		a.Zipcode AS ZIP,
		a.StreetAddress AS Street
	FROM
		Patients AS p
		LEFT JOIN Addresses a
			ON p.PId = a.PId AND p.RId=a.RId
	WHERE
		p.Phone IS NOT NULL AND p.Phone != ''
	ORDER BY
		p.PId
SQL
	}

	return $sth;
}

sub _add_contact {
	my ($dbi, $params) = @_;

	my $phone_object = $params->{'phone_object'};
	my $PhoneId = _get_phone_id($dbi, $phone_object->{'Phone'}, $phone_object->{'ProviderId'});

	# add phone number if does not exists
	if (!$PhoneId) {
		my $sth = $dbi->prepare(<<SQL);
INSERT phone_book (Phone, ProviderId, Registered, InvitationCode,InvitationCodeDate, MessageLimit, active)
VALUES (?, ?, sysdate(), ?, sysdate(), ?, ?)
SQL
		print "adding [".$phone_object->{'Phone'}."]\n";
		$sth->execute(
			$phone_object->{'Phone'},
			$phone_object->{'ProviderId'},
			$phone_object->{'InvitationCode'},
			$phone_object->{'MessageLimit'},
			$phone_object->{'active'},
		);

		$PhoneId =_get_phone_id($dbi, $phone_object->{'Phone'},$phone_object->{'ProviderId'});
	}


	my $PPId = _get_contact($dbi, $PhoneId, $params->{patient_id})->[0];
	#add contact if does not exists
	if (!$PPId) {
		my $sth = $dbi->prepare(<<SQL);
INSERT phone_patient (PhoneId, PId)
VALUES (?, ?)
SQL

		$sth->execute($PhoneId,$params->{patient_id});

		$PPId = _get_contact($dbi, $PhoneId, $params->{patient_id})->[0];
	}

	#add visibility if does not exists
	if( !($#{_get_visibility($dbi, $PPId, $params->{'ACL'})} + 1) ) {
		my $sth = $dbi->prepare(<<SQL);
INSERT phone_visibility (PPId, RId)
VALUES (?, ?)
SQL
		$sth->execute($PPId,$params->{'ACL'});
	}
	return 1;
}

sub _get_phone_id {
	my ($dbi, $Phone, $ProviderId) = @_;

	my $sth = $dbi->prepare(<<SQL);
SELECT
	PhoneId
FROM
	phone_book
WHERE
	Phone = ? AND
	ProviderId = ?
SQL

	$sth->execute($Phone,$ProviderId);
	return scalar $sth->fetchrow_array();
}

sub _get_contact{
	my ($dbi, $PhoneId, $patient_id) = @_;
	my $str = ($patient_id) ? " and PId = $patient_id" : '';

	return $dbi->selectcol_arrayref(<<SQL);
		SELECT
			PPId
		FROM
			phone_patient
		WHERE
			PhoneId = $PhoneId
		$str
SQL
}

sub _get_visibility{
	my ($dbi, $PPId, $ACL) = @_;
	my $str = ($ACL) ? " AND RId = $ACL" : '';

	return $dbi->selectcol_arrayref(<<SQL);
		SELECT
			RId
		FROM
			phone_visibility
		WHERE
			PPId = $PPId
		$str
SQL
}

1;
