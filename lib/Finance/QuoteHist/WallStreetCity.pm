package Finance::QuoteHist::WallStreetCity;

use strict;
use vars qw($VERSION @ISA);
use Carp;

$VERSION = '0.02';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use Date::Manip;

# Example URL:
#
# http://host.wallstreetcity.com/wsc2/Historical_Quotes.html?template=hisquote.htm&Symbol=SFA&Button=Get+Quotes&StartDate=02%2F28%2F01&Type=0&EndDate=02%2F28%2F02&Format=0
#
# Wall Street City appears to have no chunking limits on queries.

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
  # Also, Wall Street City wants 2 digit years
  my $date_pat = qr(^\s*\d{2}(\d{2})(\d{2})(\d{2}));

  # Make sure date boundaries are pre-sorted.
  if ($start_date gt $end_date) {
    ($start_date, $end_date) = ($end_date, $start_date);
  }

  my($sy, $sm, $sd) = $start_date =~ /$date_pat/;
  my($ey, $em, $ed) = $end_date   =~ /$date_pat/;
  my $start = join('%2F', $sm, $sd, $sy);
  my $end   = join('%2F', $em, $ed, $ey);

  my $url = 'http://host.wallstreetcity.com/wsc2/Historical_Quotes.html?template=hisquote.htm';
  $url .= "&Symbol=$symbol&Button=Get+Quotes&StartDate=$start&Type=0&EndDate=$end&Format=0";

  $url;
}

sub currency {
  # If the Wall Street City site ever does on-the-fly currency conversion, this
  # method can reflect/set the currency specified in the query.
  $Default_Currency;
}

1;

__END__

=head1 NAME

Finance::QuoteHist::WallStreetCity - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::WallStreetCity;
  $q = new Finance::QuoteHist::WallStreetCity
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

Finance::QuoteHist::WallStreetCity is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the Wall Street City web site
(I<http://www.wallstreetcity.com/>). Wall Street City does not
currently supply information on dividend distributions or splits.

At the time of this writing, Wall Street City did not appear to have
any limits on query results, so only a single URL is required. The
C<quote_urls()> method provides the URL necessary given the date range
and symbol. This URL is automatically utilized by the native methods
of Finance::QuoteHist::Generic.

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

In the case of Wall Street City, as of February 28, 2002, their
statement reads, in part:

 You may store in the memory of your computer and may manipulate,
 analyze, reformat, printed and/or display for your use only the
 information received or accessed through the Telescan System pursuant
 to this Subscriber Agreement.  You may not resell, redistribute,
 broadcast or transfer the information or use the information in a
 searchable, machine-readable database.  Unless separately and
 specifically authorized in writing by an officer of Telescan, you may
 not rent, lease, sublicense, distribute, transfer, copy, reproduce,
 publicly display, publish, adapt, store or time-share the Telescan
 System, any part thereof, or any of the information received or
 accessed therefrom to or through any other person or entity.


There you have it. If you feel like you might have concerns with this
then first double check the full text on this page:

  http://host.wallstreetcity.com/wsc2/License_Agreement.html

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2002 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
