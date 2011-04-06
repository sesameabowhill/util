package Repair::NewsletterArticleStat;

use strict;
use warnings;

use pQuery;

use base 'Repair::Newsletters';

sub on_newsletter_found {
	my ($self, $client_data, $file, $ppn) = @_;

	if ($ppn->{'recipient_count'} > 0) {
		my $html = pQuery($file);
		$html->find('.article_body .nl_link')->each(
			sub {
				my $href = $_->getAttribute('href');
				my $title = $_->as_text();
				if ($href =~ m{^#.*_c$}) {
					$self->{'logger'}->printf_slow(
						"CLIENT [%s]: standard article %s %s",
						$client_data->get_username(),
						$href,
						$title,
					);
					$self->find_standard_article($client_data, $title, $ppn);
				}
			}
		);
	}
	else {
		$self->{'logger'}->register_category('test newsletter sent');
	}
}

sub find_standard_article {
	my ($self, $client_data, $title, $ppn) = @_;

	$self->{'logger'}->register_category('standard article');

}

1;