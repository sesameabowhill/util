use strict;

use lib qw(.);

use Sesame::Error;
use Voice::DB;
use Sesame::Unified::DB;
use Sesame::Unified::Client;
use Voice::Factory;
use Voice::Upload::PatientPhones;
use Voice::AreaCode;

print $INC{'Voice/Upload/PatientPhones.pm'},"\n";

my %phone;
print "read data\n";
{
    
    open(my $f, '<', 'phones.csv') or die "can't read data: $!";
    my @columns = map {trim($_)} split /\t/, <$f>;
    while(<$f>) {
	my %r;
	@r{ @columns } = map {trim($_)} split /\t/, $_;
	my @d = split /\./, $r{BirthDate};
	$r{BirthDate} = $d[2].'-'.$d[1].'-'.$d[0];
	$phone{$r{BirthDate}}{$r{FName}}{$r{LName}} = $r{OtherPhone};
    }
    close($f);
}
#	use Data::Dumper;
#	print Dumper(\%phone);

my $client = Sesame::Unified::Client->new('db_name', 'berkshiredg');

my $voice_dbh = Voice::DB->connect();
my $client_dbh = Sesame::Unified::DB->get_client_db_connection($client);
my $factory = Voice::Factory->new(
    $voice_dbh,
    $client_dbh,
    { 'category' => $client->get_client_type() },
);
my $phones_interface = Voice::Upload::PatientPhones->new($client_dbh, $client->get_client_type());

print "get zip codes\n";
my $need_zc = $phones_interface->get_patients_zipcodes();

print "get area codes\n";
my $zipcodes = Voice::AreaCode::get_areacode_by_zip( $voice_dbh, $need_zc );

$phones_interface->init_zip_codes($zipcodes);
print "fill phone book\n";
$phones_interface->fill_phone_book(\%phone);


sub trim {
    my ($str) = @_;
    $str =~ s/\s+$//;
    $str =~ s/^\s+//;
    return $str;
}