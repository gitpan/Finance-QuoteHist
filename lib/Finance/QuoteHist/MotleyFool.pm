package Finance::QuoteHist::MotleyFool;

use strict;
use vars qw($VERSION @ISA);
use Carp;

$VERSION = '0.21';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use Date::Manip;

# Example URL:
#
# http://quote.fool.com/historical/historicalquotes.asp?startmo=03&startday=1&startyr=1999&endmo=03&endday=31&endyr=1999&period=daily&symbols=PUMA&currticker=PUMA
#
# The Fool returns data in 30 day increments, so tis best to parse
# monthly.

my $Default_Currency = 'USD';

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
  $parms{reverse} = 1 unless defined $parms{reverse};
  my $self = Finance::QuoteHist::Generic->new(%parms);
  bless $self, $class;
  $self;
}

sub quote_urls {
  my($self, $symbol, $start_date, $end_date) = @_;
  $symbol or croak "Symbol required\n";
  $start_date = $self->start_date unless $start_date;
  $end_date   = $self->end_date   unless $end_date;

  # For splitting dates of the form 'YYYYMMDD'
  my $date_pat = qr(^\s*(\d{4})(\d{2})(\d{2}));

  # Make sure date boundaries are pre-sorted.
  if ($start_date gt $end_date) {
    ($start_date, $end_date) = ($end_date, $start_date);
  }

  # Break date range into 30 day blocks (last block might
  # end up being less than 30 days)
  my(%date_pairs, $low_date, $high_date);
  $low_date = $start_date;
  while (1) {
    $high_date = DateCalc($low_date,  '+ 30 days');
    last if $high_date gt $end_date;
    $date_pairs{$low_date} = $high_date;
    $low_date = DateCalc($high_date, '+ 1 day');
  }
  # Last query block only needs to extend to end_date
  $date_pairs{$low_date} = $end_date;


  my @urls;
  foreach (sort keys %date_pairs) {
    my($sy, $sm, $sd) = /$date_pat/;
    my($ey, $em, $ed) = $date_pairs{$_} =~ /$date_pat/;
    push(@urls, 'http://quote.fool.com/historical/historicalquotes.asp?' .
	 join('&', "startmo=$sm", "startday=$sd", "startyr=$sy",
	      "endmo=$em", "endday=$ed", "endyr=$ey",
	      "symbols=$symbol", "currticker=$symbol", 'period=daily'));
  }

  @urls;
}

sub currency {
  # If the Motley Fool ever does on-the-fly currency conversion, this
  # method can reflect/set the currency specified in the query.
  $Default_Currency;
}

1;

__END__

=head1 NAME

Finance::QuoteHist::MotleyFool - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::MotleyFool;
  $q = new Finance::QuoteHist::MotleyFool
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

Finance::QuoteHist::MotleyFool is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the Motley Fool web site (I<http://www.fool.com/>). Motley
Fool does not currently supply information on dividend distributions
or splits.

For quote queries in particular, at the time of this writing, the
Motley Fool web site utilizes start and end dates, but never returns
more than a month worth of data for a particular symbol. The
C<quote_urls()> method provides all the URLs necessary given the date
range and symbols. These are automatically utilized by the native
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

In the case of The Motley Fool, as of September 13, 2000, their
statement reads, in part:

  We do our best to get you timely, accurate information,
  but we reserve the right to be late, wrong, stupid, or
  even foolish. Use this data for your own information,
  not for trading. The Fool and its data or content
  providers (such as S&P Comstock, BigCharts, AFX, or
  Comtex) won't be liable for any delays or errors in the
  data, or for any losses you suffer because you relied
  upon it.

There you have it. If you feel like you might have concerns with this
then first double check the statement on the bottom of this page:

  http://quote.fool.com/historical/historicalquotes.asp

In addition, you might want to read their disclaimer:

  http://www.fool.com/help/disclaimer.htm

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
