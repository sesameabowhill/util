## $Id$
package ClientData::DB::OrthoPat;

use base qw( ClientData::DB::Ortho );

sub get_full_type {
	my ($class) = @_;
	
	return 'ortho_pat';
}





1;