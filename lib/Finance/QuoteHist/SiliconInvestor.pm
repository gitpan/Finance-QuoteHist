package Finance::QuoteHist::SiliconInvestor;

use strict;
use vars qw($VERSION @ISA);
use Carp;

$VERSION = '0.02';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use Date::Manip;

# Example URL:
#
# http://www.siliconinvestor.com/research/historical.gsp?s=PMRX&c=0&n=0&o=a&fm=8&fd=16&fy=1997&tm=11&td=16&ty=1998
#
# Silicon Investor returns data 200 entries at a time.
#
# This was added as a replacement source for defunct tickers, since
# Financial Web ceased supporting defunct symbols.

my $Default_Currency = 'USD';

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
#  $parms{reverse} = 1 unless defined $parms{reverse};
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

  # Returns data 200 rows at a time. Assuming a 5 business day week,
  # this amounts to 40 weeks. Therefore we can break queries across
  # 40*7=280 day blocks and remain within our 200 rows.
  my(%date_pairs, $low_date, $high_date);
  $low_date = $start_date;
  while (1) {
    $high_date = DateCalc($low_date,  '+ 280 days');
    last if Date_Cmp($high_date, $end_date) == 1;
    $date_pairs{$low_date} = $high_date;
    $low_date = DateCalc($high_date, '+ 1 day');
  }
  # Last query block only needs to extend to end_date
  $date_pairs{$low_date} = $end_date;

  my @urls;
  foreach (sort keys %date_pairs) {
    my($sy, $sm, $sd) = /$date_pat/;
    my($ey, $em, $ed) = $date_pairs{$_} =~ /$date_pat/;
    # o=a means ascending order. c and n are unknown quantities
    push(@urls, 'http://www.siliconinvestor.com/research/historical.gsp?' .
	 join('&', "s=$symbol", 'c=0', 'n=0', 'o=a',
	      "fm=$sm", "fd=$sd", "fy=$sy",
	      "tm=$em", "td=$ed", "ty=$ey"));
  }

  @urls;
}

sub currency {
  # If Silicon Investor ever does on-the-fly currency conversion, this
  # method can reflect/set the currency specified in the query.
  $Default_Currency;
}

1;

__END__

=head1 NAME

Finance::QuoteHist::SiliconInvestor - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::SiliconInvestor;
  $q = Finance::QuoteHist::SiliconInvestor->new
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

Finance::QuoteHist::SiliconInvestor is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the Silicon Investor web site
(I<http://www.siliconinvestor.com/>). Silicon Investor does not
currently supply information on dividend distributions or splits.

For quote queries in particular, at the time of this writing, the
Silicon Investor web site utilizes start and end dates, returns data
200 entries at a time. The C<quote_urls()> method provides all the
URLs necessary given the date range and symbols. These are
automatically utilized by the native methods of
Finance::QuoteHist::Generic.

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
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
B<Open>, B<High>, B<Low>, B<Close>, and B<Volume> for that date. Quote
values are pre-adjusted for this site.

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

In the case of The Silicon Investor, as of November 27, 2000, their
statement reads, in part:

 All information provided by S&P ComStock, Inc. ("ComStock") and its
 affiliates (the "ComStock Information") on Silicon Investor World
 Wide Web site is owned by or licensed to ComStock and its affiliates
 and any user is permitted to store, manipulate, analyze, reformat,
 print and display the ComStock Information only for such user's
 personal use. In no event shall any user publish, retransmit,
 redistribute or otherwise reproduce any ComStock Information in any
 format to anyone, and no user shall use any ComStock Information in
 or in connection with any business or commercial enterprise,
 including, without limitation, any securities, investment,
 accounting, banking, legal or media business or enterprise.

There you have it. If you feel like you might have concerns with this
then first double check the statement on the bottom of this page:

  http://www.siliconinvestor.com/misc/terms.html

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
