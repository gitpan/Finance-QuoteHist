package Finance::QuoteHist::Yahoo;

use strict;
use vars qw($VERSION @ISA);
use Carp;

$VERSION = '0.21';

use Finance::QuoteHist::Generic;
@ISA = qw(Finance::QuoteHist::Generic);

use Date::Manip;

# Example URL:
#
# http://chart.yahoo.com/t?a=01&b=01&c=99&d=03&e=01&f=00&g=d&s=SFA&y=0
#
# Example for CSV output:
#
# http://chart.yahoo.com/t?a=01&b=01&c=99&d=03&e=01&f=00&g=d&s=SFA&y=0&q=q&x=.csv
#
# For CSV output, date ranges are unlimited; the output is adjusted
# and does not include any split or dividend notices.
#
# For HTML output, Yahoo takes arbitrary date ranges, but returns
# results in batches of 200, so we use 200 day blocks. Output is
# non-adjusted, but includes an adjusted close column as well as split
# and dividend notices.
#
# Yahoo also includeds split and dividend information; these are
# captured row by row by overiding the non_quote_row method. For the
# date range specified, these can be examined with dividends() and
# splits().

my $Default_Currency = 'USD';

# Tweak values for the all-might 'g' parameter. There is no
# special-purpose query for splits like there is dividends, so we have
# to use the regular quote interface and filter out the split
# notices. I thought I could save some bandwidth by snagging the
# splits in the monthly timeblock quote option (mode 'm'), but alas,
# the dates are trimmed to represent only the month and year -- we
# must stick to the daily values; it's still far quicker than the
# other sites since we can use 200 day blocks, though.
my %Gmodes = (
	      quote    => 'd',
	      dividend => 'v',
	      split    => 'd',
	     );

sub new {
  my $that = shift;
  my $class = ref($that) || $that;
  my %parms = @_;

  # With both HTML and CSV, Yahoo returns results newest on top
  $parms{reverse} = 1 unless defined $parms{reverse};

  # Yahoo has non-adjusted data available, but only in HTML mode.
  $parms{has_non_adjusted} = 1 unless defined $parms{has_non_adjusted};

  my $source_type;
  if ($source_type = $parms{source_type}) {
    delete $parms{source_type};
  }

  my $self = Finance::QuoteHist::Generic->new(%parms);
  bless $self, $class;

  $self->source_type($source_type ? $source_type : 0);

  $self;
}

# Yahoo can fetch dividends and splits. Both can be extracted from the
# HTML quote results; dividends can also be fetched directly, but not
# splits.

# Not so direct query
sub splits {
  # An HTML quote query is the only way to go for splits on yahoo, so
  # we have to signal to ourselves what the source mode should be so
  # that the _urls() method will generate the proper URL...otherwise
  # we would get CSV, which has no split info.
  my $self = shift;
  my $ost = $self->source_type;
  $self->source_type('html');
#  $self->quote_get;
  my $rows = $self->SUPER::splits(@_);
  $self->source_type($ost ? $ost : 0);
#  $self->extraction('split');
  wantarray ? @$rows : $rows;
}

sub quote_labels {
  # Override. In HTML mode, we have an Adjusted value column, but not
  # in CSV since everything is pre-adjusted.
  my $self = shift;
  my @normal_labels = $self->SUPER::quote_labels();
  if (!$self->adjusted || $self->source_type eq 'html') {
    return (@normal_labels, 'Adj');
  }
  @normal_labels;
}

sub extractors {
  # Override. If we are pulling CSV, save some time by skipping
  # extraction attempts
  my $self = shift;
  $self->source_type eq 'csv' ? () : $self->SUPER::extractors();
}

# Let the monster _urls() method take care of the details of both
# target type and content type.

sub quote_urls    { shift->_urls('quote',    @_) }
sub dividend_urls { shift->_urls('dividend', @_) }

sub _urls {
  my($self, $mode, $ticker, $start_date, $end_date) = @_;
  $ticker or croak "Ticker symbol required\n";
  $mode   or croak "Gmode required\n";
  my $gval = $Gmodes{$mode} or croak "Unknown url mode ($mode)\n";

  $start_date = $self->start_date unless $start_date;
  $end_date   = $self->end_date   unless $end_date;

  # For splitting dates of the form 'YYYYMMDD'
  my $date_pat = qr(^\s*(\d{4})(\d{2})(\d{2}));

  # Make sure date boundaries are pre-sorted.
  if ($start_date gt $end_date) {
    ($start_date, $end_date) = ($end_date, $start_date);
  }

  my(%date_pairs, $source_mode);

  # Source type can be overridden, via prior setting via
  # source_type(). This is what happens when grabbing splits, for
  # instance.
  if ($self->source_type) {
    $source_mode = $self->source_type;
  }
  else {
    # HTML is not preadjusted, but includes an adjusted close. CSV is
    # preadjusted for all values. The only time we drop into HTML mode
    # with a direct quote query is if values have been specifically
    # requested to be non-adjusted.
    if ($mode eq 'dividend') {
      $source_mode = 'csv';
    }
    elsif ($mode eq 'quote') {
      $source_mode = $self->{adjusted} ? 'csv' : 'html';
    }
  }

  # Heads up for friends such as extractors() that optimize based on
  # output type.
  $self->source_type($source_mode);

  if ($source_mode ne 'html') {
    # Single date block for CSV retrievals; Yahoo does not limit the
    # query range for CSV results.
    $self->parse_mode('csv');
    $date_pairs{$start_date} = $end_date;
    # hack for munged CSV on Yahoo...see csv_parser() below
    ++$self->{_yahoo_div_fix} if $mode eq 'dividend';
  }
  elsif ($mode eq 'dividend') {
    # In case we're being forced to do a direct dividend query in HTML
    # mode, we might as well make it a single date block because Yahoo
    # does not limit dividend queries, either.
    $self->parse_mode('html');
    $date_pairs{$start_date} = $end_date;
  }
  else {
    # 200 day block limit for HTML quote queries
    $self->parse_mode('html');
    my($low_date, $high_date);
    $low_date = $start_date;
    while (1) {
      $high_date = DateCalc($low_date,  '+ 200 days');
      last if $high_date gt $end_date;
      $date_pairs{$low_date} = $high_date;
      $low_date = DateCalc($high_date, '+ 1 day');
    }
    # Last query block only needs to extend to end_date
    $date_pairs{$low_date} = $end_date;
  }

  my @urls;
  foreach (sort keys %date_pairs) {
    my($sy, $sm, $sd) = /$date_pat/;
    my($ey, $em, $ed) = $date_pairs{$_} =~ /$date_pat/;
    push(@urls, 'http://chart.yahoo.com/t?' .
	 join('&', "a=$sm", "b=$sd", "c=$sy",
	      "d=$em", "e=$ed", "f=$ey",
	      "g=$gval", "s=$ticker"));
    $urls[-1] .= '&q=q&x=.csv' if $source_mode eq 'csv';
  }

  @urls;
}

sub dividend_extract {
  # Get a row as array ref, see if it contains dividend info. If so,
  # return another array ref with the extracted info.
  my($self, $row) = @_;
  croak "row as array ref required\n" unless ref $row;
  # Use the current label map since we're an extractor
  my $date_column = $self->target_label_map->{date};
  
  # This is a munge...not sure how to abstract this column.
  # (it might not be the same column as a direct query)
  my $div_column  = 1;

  # example dividend: "$0.01 Cash Dividend"
  my($div) = $row->[$div_column] =~ /\$*(\d*\.\d+).*Dividend/i;
  return undef unless defined $div;
  [ $row->[$date_column], $row->[$div_column] ];
}

sub split_extract {
  my($self, $row) = @_;
  croak "row as array ref required\n" unless ref $row;

  # Use the current label map since we're an extractor
  my $date_column = $self->target_label_map->{date};

  # This is a munge...not sure how to abstract this column.
  # (it might not be the same column as a direct query)
  my $split_column = 1;

  # example split: "3:1 Stock Split (before market open)"
  my($post, $pre) = $row->[$split_column] =~ /(\d+):(\d+).*Split/i;
  return undef unless $post && $pre;
  [ $row->[$date_column], $post, $pre ];
}

sub currency {
  # If yahoo ever starts supporting on-the-fly currency conversion,
  # this method can be a bit more elaborate to match/set the query.
  $Default_Currency;
}

### Added methods

sub source_type {
  # Force our souce data type (HTML/CSV). If unspecified, we pick the
  # quickest and most appropriate based on parameters. Sometimes we
  # might want to force HTML mode, though.
  my($self, $type) = @_;
  if (defined $type) {
    if ($type eq 'html' || $type eq 'csv') {
      $self->{source_type} = $type;
    }
    elsif ($type == 0) {
      $self->{source_type} = '';
    }
    else {
      croak "Unknown source type ($type)\n";
    }
  }
  $self->{source_type};
}

### Ugly overrides

sub csv_parser {
  # Nasty hack. Yahoo provides regular CSV data for quotes, but for
  # dividends the headers use a comma and the data use a space as the
  # separator. At least this won't break anything if Yahoo suddenly
  # decides to fix their dividend CSV data.
  my $self = shift;
  my $csv_string = shift;
  # Our warning gets set up in the _urls() method. Blech.
  if ($self->{_yahoo_div_fix}) {
    # dodges header line
    $csv_string =~ s/(\n\S+)\s+/$1,/sg;
    delete $self->{_yahoo_div_fix};
  }
  $self->SUPER::csv_parser($csv_string, @_);
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

  # Adjusted values
  foreach $row ($q->quotes()) {
    ($date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

  # Non adjusted values
  $q->adjusted(0);
  foreach $row ($q->quotes()) {
     ($date, $open, $high, $low, $close, $volume, $adj_close) = @$row;
  }

  # Splits
  foreach $row ($q->splits()) {
     ($date, $post, $pre) = @$row;
  }

  # Dividends
  foreach $row ($q->dividends()) {
     ($date, $dividend) = @$row;
  }

=head1 DESCRIPTION

Finance::QuoteHist::Yahoo is a subclass of
Finance::QuoteHist::Generic, specifically tailored to read historical
quotes, dividends, and splits from the Yahoo web site
(I<http://charts.yahoo.com/>).

For quotes and dividends, Yahoo can return data quickly in CSV
format. For quotes, non-adjusted values are available in HTML. Splits
are only found embedded in the non-adjusted HTML produced for
quotes. Behind the scenes, an HTML quote query is performed when
splits are requested; quotes are retained based on the first
successful query type. Unless told otherwise, via the C<adjusted()>
method, the non-adjusted quotes will be automatically adjusted by
applying the ratio derived from the adjusted closing value and
non-adjusted closing value. This does not apply if quotes were
retrieved using CSV.

There are no date range restrictions on CSV queries for quotes and
dividends.

For HTML queries, Yahoo takes arbitrary date ranges as arguments, but
breaks results into pages of 200 entries.

The C<quote_urls()> and C<dividend_urls> methods provide all the URLs
necessary given the target, date range, and symbols, whether they be
for HTML or CSV data. These are automatically utilized by the native
methods of Finance::QuoteHist::Generic.

Please see L<Finance::QuoteHist::Generic(3)> for more details on usage
and available methods. If you just want to get historical quotes and
are not interested in the details of how it is done, check out
L<Finance::QuoteHist(3)>.

=head1 METHODS

The basic user interface consists of four methods, as seen in the
example above. Those methods are:

=over

=item quotes()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Date>, B<Open>,
B<High>, B<Low>, B<Close>, and B<Volume> for that date. Optionally, if
non-adjusted values were requested, their will be an extra element at
the end of the row for the B<Adjusted> closing price.

=item dividends()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Date> and amount
of the B<Dividend>, in that order.

=item splits()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Date>, B<Post>
split shares, and B<Pre> split shares, in that order.

=item adjusted($boolean)

Sets whether adjusted or non-adjusted quotes are desired. Quotes are
pre-adjusted by default.

=back

There are some extra methods and overridden methods in the Yahoo class
that deserve a little explanation for developers interested in
developing a similar site-specific module:

=over

=item source_type($type)

Sets or returns the desired type of output from Yahoo. Valid settings
are 'csv' and 'html'. By default this is 'csv', where possible, but
will sometimes be set to 'html' in cases where there is no choice,
such as when split information is requested. In these cases, the
desired source type is temporarily saved for the duration of the query
and restored afterwards.

=back

The following methods override methods provided by the
Finance::QuoteHist::Generic module; more of this was necessary than is
typical for a basic query site due to the variety of query types and
data formats available on Yahoo.

=over

=item quote_urls()

=item dividend_urls()

Provides the URLs necessary for direct quote and dividend queries;
depending on the value returned by the C<source_type()> method, these
URLs are either for HTML or CSV data.

=item dividend_extract()

=item split_extract()

The presence of these filters will lift dividend and split information
from the regular HTML quote output of Yahoo. In the case of splits,
this is the only way to get the information, hence there is no
C<split_urls()> method present.

=item split_get()

The mere presence of the C<split_extract()> method would normally be
enough for extraction retrieval. In this case, however, the data must
be in HTML format. By overriding the method, 'html' can be
specifically (and temporarily) requested for the duration of the
query since the split information is not present in the CSV formats.

=item csv_parser()

Unfortunate hack. Yahoo just happens to return CSV data from direct
dividend queries in a mangled format (the CSV separator is different
for the header row vs. the rest of the rows). This corrects that
before passing it along to the regular C<csv_parser()> method.

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

In the case of Yahoo, as of September 13, 2000, their statement reads,
in part:

    Historical chart data and daily updates provided by
    Commodity Systems, Inc. (CSI). Data and information is 
    provided for informational purposes only, and is not
    intended for trading purposes. Neither Yahoo nor any of
    its data or content providers (such as CSI) shall be
    liable for any errors or delays in the content, or for
    any actions taken in reliance thereon.

If you would like to know more, check out where this statement was
found:

  http://chart.yahoo.com/d

Better yet, you might want to read their disclaimer page:

  http://www.yahoo.com/info/misc/disclaimer.html

If you still have concerns, then use another site-specific
historical quote instance, or none at all.

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
