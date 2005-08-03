package Finance::QuoteHist::QuoteMedia;

use strict;
use vars qw($VERSION @ISA);
use Carp;

$VERSION = '1.00';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use Date::Manip;

# Example URL:
#
# http://app.quotemedia.com/data/getHistoryDownload.csv?symbol=IBM&startDay=2&startMonth=4&startYear=2004&endDay=2&endMonth=5&endYear=2005

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
  my $self = __PACKAGE__->SUPER::new(%parms);
  bless $self, $class;
  $self->parse_mode('csv');
  $self;
}


sub url_maker {
  my($self, %parms) = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  my $parse_mode  = $parms{parse_mode}  || $self->parse_mode;
  return undef unless $target_mode eq 'quote' && $parse_mode eq 'csv';
  my($ticker, $start_date, $end_date) =
    @parms{qw(symbol start_date end_date)};
  $start_date ||= $self->start_date;
  $end_date   ||= $self->end_date;
  if ($start_date && $end_date && $start_date gt $end_date) {
    ($start_date, $end_date) = ($end_date, $start_date);
  }

  my $host = 'app.quotemedia.com';
  my $cgi  = 'data/getHistoryDownload.csv';


  my $make_url_str = sub {
    my($sd, $sm, $sy, $ed, $em, $ey) = @_;
    my $base_url = "http://$host/$cgi?";
    my @base_parms = (
      "symbol=$ticker",
      "startDay=$sd", "startMonth=$sm", "startYear=$sy",
      "endDay=$ed",   "endMonth=$em",   "endYear=$ey"
    );
    $base_url .  join('&', @base_parms);
  };

  if ($start_date) {
    my($sy, $sm, $sd) = $self->ymd($start_date);
    my($ey, $em, $ed) = $self->ymd($end_date);
    $sm -= 1; $em -= 1;
    my @urls = $make_url_str->($sd, $sm, $sy, $ed, $em, $ey);
    return sub { pop @urls };
  }
  else {
    # use year chunks
    my($year, $em, $ed) = $self->ymd($end_date);
    $em -= 1;
    my($sm, $sd) = (0, 1);
    return sub {
      my $url = $make_url_str->($sd, $sm, $year, $ed, $em, $year);
      --$year;
      $em = 11; $ed = 31;
      $url;
    }
  }
}

1;

__END__

=head1 NAME

Finance::QuoteHist::QuoteMedia - Site-specific class for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::QuoteMedia;
  $q = Finance::QuoteHist::QuoteMedia->new
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

Finance::QuoteHist::QuoteMedia is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes from the QuoteMedia web site (I<http://www.quotemedia.com/>).
Note that Quotemedia is currently the site that provides historical
quote data for such other sites as Silicon Investor, which was the topic
of an earlier module in this distribution.

Quotemedia does not currently provide information on dividends or
splits.

For quote queries in particular, at the time of this writing, the
Quotemedia web site utilizes start and end dates with no apparent limit
on the number of results returned. Results are returned in CSV format.

Please see L<Finance::QuoteHist::Generic(3)> for more details on usage
and available methods. If you just want to get historical quotes and are
not interested in the details of how it is done, check out
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
adaptive under these circumstances, they will at some point probably be
unable to retrieve data unless fixed or provided with new parameters.
Furthermore, the data from these web sites is usually not even
guaranteed by the web sites themselves, and oftentimes is acquired
elsewhere.

Details for Quotemedia's terms of use can be found here:
I<http://www.quotemedia.com/termsofusetools.php>

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2005 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
