package Finance::QuoteHist::FinancialWeb;

use strict;
use vars qw($VERSION @ISA);
use Carp;

$VERSION = '0.21';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

# Example URL:
#
# http://www.financialweb.com/mkthistory.asp?symbol=sfa&startdate=5/1/1998&format=4&submit=1
#
# FinancialWeb only returns data in year-long blocks, starting with the
# start date, assuming, of course, that there is at least a years worth
# of data after that date. The date is tantalizingly labeled "startdate"
# in the URL, but so far "enddate" and "stopdate" do not seem to have
# an effect.
#
# Table layout:
# Date Close "Day High" "Day Low" Open Volume
#
# HTML::TableExtract will remap with the default Finance::QuoteHist
# mappings, though.

my $Default_Currency = 'USD';

sub quote_urls {
  my($self, $symbol, $start_date, $end_date) = @_;
  $symbol or croak "Symbol required\n";
  $start_date = $self->start_date unless $start_date;
  $end_date   = $self->end_date   unless $end_date;

  my $sy = ($self->ymd($start_date))[0];
  my $ey = ($self->ymd($end_date))[0];

  my @urls;
  foreach my $y ($sy .. $ey) {
    push(@urls, "http://www.financialweb.com/mkthistory.asp?symbol=$symbol&startdate=$y/01/01&format=4&submit=1");
  }
  @urls;
}

sub currency {
  # If Financial Web ever does on-the-fly currency conversion, this
  # method can reflect/set the currency specified in the query.
  $Default_Currency;
}

1;

__END__

=head1 NAME

Finance::QuoteHist::FinancialWeb - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::FinancialWeb;
  $q = new Finance::QuoteHist::FinancialWeb
     (
      symbols    => [qw(IBM UPS AMZN)],
      start_date => '01/01/1999',
      end_date   => 'today',      
     );

  foreach $row ($q->quotes()) {
    ($symbol, $date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

=head1 DESCRIPTION

Finance::QuoteHist::FinancialWeb is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the FinancialWeb web site
(I<http://www.financialweb.com>). FinancialWeb does not offer
information regarding dividends or splits.

For quote queries, at the time of this writing, the Financial web site
utilizes only start dates, and returns a years worth of data if
available. The C<quote_urls()> method provides all the URLs necessary
given the date range. These are automatically utilized by the native
methods of Finance::QuoteHist::Generic.

Please see L<Finance::QuoteHist::Generic(3)> for more details on usage
and available methods. If you just want to get historical quotes and
are not interested in the details of how it is done, check out
L<Finance::QuoteHist(3)>.

=head1 METHODS

The basic user interface consists of a single method, as shown in the
example above. That method is:

=over

=item quotes()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Date>, B<Open>,
B<High>, B<Low>, B<Close>, and B<Volume> for that date. Quote values
are pre-adjusted for this site.

=back

=head1 REQUIRES

Finance::QuoteHist::Generic

=head1 DISCLAIMER

The data returned from these modules is in no way guaranteed, nor are
the developers responsible in any way for how this data (or lack
thereof) is used. The interface is based on URLs and page layouts that
might change at any time. Even though these modules are designed to be
adaptive under these circumstances, they will at some point probably
be unable to retrieve data unless fixed or provided with new
parameters. Furthermore, the data from these web sites is usually not
even guaranteed by the web sites themselves, and oftentimes is
acquired elsewhere.

In the case of FinancialWeb, as of September 13, 2000, their statment
reads, in part:

  This data may be used for PERSONAL USE ONLY. Any
  redistribution of this data, including publishing it
  in whole or in part, or publishing any calculations
  derived from it, on the internet I<(sic)> or in any
  other public forum, is illegal.

There you have it. If you feel like you might have concerns with this
then first double check the statement on their web site:

  http://www.financialweb.com/

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
