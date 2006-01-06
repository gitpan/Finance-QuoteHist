package Finance::QuoteHist::Yahoo;

use strict;
use vars qw(@ISA);
use Carp;

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use Date::Manip;
Date::Manip::Date_Init("TZ=GMT");

# Example for HTML output:
#
# http://finance.yahoo.com/q/hp?s=IBM&a=00&b=2&c=1800&d=04&e=8&f=2005&g=d&z=66&y=66
#
#   * s - ticker symbol
#   * a - start month
#   * b - start day
#   * c - start year
#   * d - end month
#   * e - end day
#   * f - end year
#   * g - resolution (e.g. 'd' is daily)
#   * y is the offset (cursor) from the start date
#   * z is the number of results to return starting at the cursor (66
#     maximum, apparently)
#
# Note alternate url:
# http://table.finance.yahoo.com/d?a=1&b=1&c=1800&d=3&e=1&f=2006&s=yhoo&y=200&g=d
#
# Example for CSV output:
#
# http://ichart.finance.yahoo.com/table.csv?s=IBM&a=00&b=2&c=1800&d=04&e=8&f=2005&g=d&ignore=.csv
#
# (historically could use table.finance.yahoo.com as well)
#
# Note that Yahoo implements month numbering with Jan=0 and Dec=11.
#
# For CSV output, date ranges are unlimited; the output is adjusted and
# does not include any split or dividend notices.
#
# URL for splits and dividends:
#
# These are either extracted from within the historical quote results
# (non_quote_row()) or found directly:
#
# http://finance.yahoo.com/q/hp?s=IBM&a=00&b=2&c=1800&d=04&e=8&f=2005&g=v
# http://table.finance.yahoo.com/table.csv?s=IBM&a=00&b=2&c=1800&d=04&e=8&f=2005&g=v&ignore=.csv

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;

  $parms{parse_mode} ||= 'csv';

  my $self = __PACKAGE__->SUPER::new(%parms);
  bless $self, $class;

  $self->set_label_pattern(
    target_mode => 'dividend',
    parse_mode  => 'html',
    label       => 'div',
    pattern     => qr/(Open|Div)/
  );

  $self;
}

# Yahoo can fetch dividends and splits. They can be extracted from
# regular quote results or queried directly.

# Not so direct query
sub splits {
  # An HTML quote query is the only way to go for splits on yahoo, so
  # we have to signal to ourselves what the source mode should be so
  # that the _urls() method will generate the proper URL...otherwise
  # we would get CSV, which has no split info.
  my $self = shift;
  my $parse_mode_orig  = $self->parse_mode;
  my $target_mode_orig = $self->target_mode;
  $self->parse_mode('html');
  $self->target_mode('dividend');
  my $rows = $self->dividends(@_);
  $self->parse_mode($parse_mode_orig);
  $self->target_mode($target_mode_orig);
  $self->result_rows('split');
}

sub labels {
  my $self = shift;
  my %parms = @_;
  my $target_mode = $self->target_mode;
  my @labels = $self->SUPER::labels(%parms);
  push(@labels, 'adj') if $target_mode eq 'quote';
  @labels;
}

sub extractors {
  # Override. If we are pulling CSV, save some time by skipping
  # extraction attempts
  my $self  = shift;
  my %parms = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  my $parse_mode  = $parms{parse_mode}  || $self->parse_mode;
  return () if $parse_mode eq 'csv';
  return () unless $target_mode eq 'quote' || $target_mode eq 'dividend';
  my $date_column = $self->label_column('date');
  my $split_column = 1;
  my %extractors;
  # for both quote and dividend results in html mode
  $extractors{'split'} = sub {
    my $row = shift;
    die "row as array ref required" unless ref $row;
    # example split: "3 : 1 Stock Split"
    my($post, $pre) = $row->[$split_column] =~ /(\d+)\s*:\s*(\d+).*Split/i;
    return undef unless $post && $pre;
    [ $row->[$date_column], $post, $pre ];
  };
  if ($target_mode eq 'quote') {
    my $div_column = 1;
    $extractors{dividend} = sub {
      # Get a row as array ref, see if it contains dividend info. If so,
      # return another array ref with the extracted info.
      my $row = shift;
      die "row as array ref required\n" unless ref $row;
      # example dividend: "$0.01 Cash Dividend"
      my($div) = $row->[$div_column] =~ /\$*(\d*\.\d+).*Dividend/i;
      return undef unless defined $div;
      [ $row->[$date_column], $row->[$div_column] ];
    };
  }
  %extractors;
}

sub url_maker {
  my($self, %parms) = @_;
  my $target_mode = $parms{target_mode} || $self->target_mode;
  my $parse_mode  = $parms{parse_mode}  || $self->parse_mode;
  my($ticker, $start_date, $end_date) =
    @parms{qw(symbol start_date end_date)};
  $start_date ||= $self->start_date;
  $end_date   ||= $self->end_date;
  if ($start_date && $end_date && $start_date gt $end_date) {
    ($start_date, $end_date) = ($end_date, $start_date);
  }
  my @urls;
  my($host, $cgi);
  if ($parse_mode eq 'csv') {
    $host = 'ichart.finance.yahoo.com';
    $cgi  = 'table.csv';
  }
  else {
    $host = 'finance.yahoo.com';
    $cgi  = 'q/hp';
  }
  my $g = $target_mode eq 'quote' ? 'd' : 'v';
  my($sy, $sm, $sd) = $self->ymd($start_date);
  my($ey, $em, $ed) = $self->ymd($end_date);
  # yahoo is 0-based months
  $sm = sprintf("%02d", $sm - 1);
  $em = sprintf("%02d", $em - 1);
  
  $ticker ||= 'BOOLEAN';
  my $base_url = "http://$host/$cgi?";
  my @base_parms = (
    "a=$sm", "b=$sd", "c=$sy",
    "d=$em", "e=$ed", "f=$ey",
    "g=$g", "s=$ticker"
  );

  if ($parse_mode eq 'html' && $target_mode eq 'quote') {
    my $cursor = 0;
    my $window = 66;
    return sub {
      my $url = $base_url .
        join('&', @base_parms,
                 "z=$window", "y=$cursor");
      $url .= '&ignore=.csv' if $parse_mode eq 'csv';
      $cursor += $window;
      $url;
    }
  }
  else {
    @urls = $base_url .  join('&', @base_parms);
    $urls[0] .= '&ignore=.csv' if $parse_mode eq 'csv';
    return sub { pop @urls }
  }
}

1;

__END__

=head1 NAME

Finance::QuoteHist::Yahoo - Site-specific subclass for retrieving historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist::Yahoo;
  $q = new Finance::QuoteHist::Yahoo
     (
      symbols    => [qw(IBM UPS AMZN)],
      start_date => '01/01/1999',
      end_date   => 'today',
     );

  # Values
  foreach $row ($q->quotes()) {
    ($symbol, $date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

  # Splits
  foreach $row ($q->splits()) {
     ($symbol, $date, $post, $pre) = @$row;
  }

  # Dividends
  foreach $row ($q->dividends()) {
     ($symbol, $date, $dividend) = @$row;
  }

=head1 DESCRIPTION

Finance::QuoteHist::Yahoo is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes, dividends, and splits from the Yahoo web site
(I<http://table.finance.yahoo.com/>).

For quotes and dividends, Yahoo can return data quickly in CSV format.
Both of these can also be extracted from HTML tables. Splits are only
available embedded in the HTML version of dividends.

There are no date range restrictions on CSV queries for quotes and
dividends.

For HTML queries, Yahoo takes arbitrary date ranges as arguments, but
breaks results into pages of 66 entries.

Please see L<Finance::QuoteHist::Generic(3)> for more details on usage
and available methods. If you just want to get historical quotes and
are not interested in the details of how it is done, check out
L<Finance::QuoteHist(3)>.

=head1 METHODS

The basic user interface consists of three methods, as seen in the
example above. Those methods are:

=over

=item quotes()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
B<Open>, B<High>, B<Low>, B<Close>, and B<Volume> for that date.

=item dividends()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
and amount of the B<Dividend>, in that order.

=item splits()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
B<Post> split shares, and B<Pre> split shares, in that order.

=back

The following methods override methods provided by the
Finance::QuoteHist::Generic module; more of this was necessary than is
typical for a basic query site due to the variety of query types and
data formats available on Yahoo.

=over

=item url_maker()

Returns a subroutine reference tailored for the current target mode and
parsing mode. The routine is an iterator that will produce all necessary
URLs on repeated invocations necessary to complete a query.

=item extractors()

Returns a hash of subroutine references that attempt to extract embedded
values (dividends or splits) within the results from a larger query.

=item labels()

Includes the 'adj' column.

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

If you would like to know more, check out the terms of service from
Yahoo!, which can be found here:

  http://docs.yahoo.com/info/terms/

If you still have concerns, then use another site-specific historical
quote instance, or none at all.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000-2005 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist(3), perl(1).

=cut
