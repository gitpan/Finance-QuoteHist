package Finance::QuoteHist::MotleyFool;

use strict;
use vars qw($VERSION @ISA);
use Carp;

$VERSION = '0.01';

use Date::Manip;
use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

# Example URL:
#
# http://quote.fool.com/historical/historicalquotes.asp?startmo=03&startday=1&startyr=1999&endmo=03&endday=31&endyr=1999&period=daily&symbols=CORL&currticker=CORL
#
# The Fool returns data in 30 day increments, so tis best to parse
# monthly.

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
  $parms{reverse} = 1 unless defined $parms{reverse};
  my $self = new Finance::QuoteHist::Generic %parms;
  bless $self, $class;
  $self;
}

sub urls {
  my $self = shift;
  my $symbol = shift or croak "Symbol required\n";
  my $sdate  = $self->{start_date};
  my $edate  = $self->{end_date};
  my ($starty, $startm, $startd) = $self->ymd($sdate);
  my ($endy, $endm, $endd)       = $self->ymd($edate);


  my %pairs;
  foreach my $y ($starty .. $endy) {
    my $sm = $y eq $starty ? $startm : '01';
    my $em = $y eq $endy   ? $endm   : '12';
    foreach my $m ($sm .. $em) {
      my $dim = Date_DaysInMonth($m, $y);
      my $sd = $y eq $starty && $m eq $startm ? $startd : '01';
      my $ed = $y eq $endy   && $m eq $endm   ? $endd   : $dim;
      my $start = ParseDate("$y/$m/$sd");
      my $end   = ParseDate("$y/$m/$ed");
      $start =~ s/\d\d:.*//;
      $end   =~ s/\d\d:.$//;
      $pairs{$start} = $end;
    }
  }

  my @urls;
  foreach (sort keys %pairs) {
    my($sy,$sm,$sd) = $self->ymd($_);
    my($ey,$em,$ed) = $self->ymd($pairs{$_});
    push(@urls, "http://quote.fool.com/historical/historicalquotes.asp?startmo=$sm&startday=$sd&startyr=$sy&endmo=$em&endday=$ed&endyr=$ey&period=daily&symbols=$symbol&currticker=$symbol");
  }
  @urls;
}

1;

__END__

=head1 NAME

Finance::QuoteHist::MotleyFool - Perl extension for historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::MotleyFool;
  $q = new Finance::QuoteHist::MotleyFool
     (
      symbols    => [qw(IBM UPS AMZN)],
      start_date => '01/01/1999',
      end_date   => 'today',      
     );

  foreach $row ($q->getquotes()) {
    ($date $open $high $low $close $volume) = @$row;
    ...
  }

=head1 DESCRIPTION

Finance::QuoteHist::MotleyFool is a subclass of Finance::QuoteHist::Generic, specificaly tailored to read historical quotes from the Motley Fool web site
(I<http://www.fool.com/>).

In particular, at the time of this writing, the Motley Fool web site
utilizes start and end dates, but never returns more than a month worth
of data for a particular symbol.  The C<urls()> method provides all the URLS necessary given the date range and symbols.  These are automatically
utilized by the native methods of Finance::QuoteHist::Generic.

Please see L<Finance::QuoteHist::Generic(3)> for more details on usage and available methods. If you just want to get historical quotes and are not
interested in the details of how it is done, check out L<Finance::QuoteHist(3)>.

=head1 REQUIRES

Finance::QuoteHist::Generic

=head1 DISCLAIMER

The data returned from these modules is in no way guaranteed, nor
are the developers responsible in any way for how this data
(or lack thereof) is used. The interface is based on URLs and page
layouts that might change at any time. Even though these modules
are designed to be adaptive under these circumstances, they will at
some point probably be unable to retrieve data unless fixed or
provided with new parameters. Furthermore, the data from these web
sites is usually not even guaranteed by the web sites themselves,
and oftentimes is acquired elsewhere.

In the case of The Motley Fool, as of February 2nd, 2000, their
statement reads, in part:

  We do our best to get you timely, accurate information,
  but we reserve the right to be late, wrong, stupid, or
  even foolish. Use this data for your own information, not
  for trading. The Fool and its data or content providers
  (such as S&P Comstock, BigCharts, AFX, or Comtex) won't
  be liable for any delays or errors in the data, or for
  any losses you suffer because you relied upon it. 

There you have it. If you feel like you might have concerns with
this then first double check the statement on the bottom of
this page:

  http://quote.fool.com/historical/historicalquotes.asp

In addition, you might want to read their disclaimer:

  http://www.fool.com/help/disclaimer.htm

If you still have concerns, then use another site-specific
historical quote instance, or none at all.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000 Matthew P. Sisk.
All rights reserved. All wrongs revenged. This program is free
software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
