package Finance::QuoteHist;

# Simple aggregator for Finance::QuoteHist::Generic instances,
# the primary function of which is to specify the order in which
# to try the modules upon failure.

use strict;
use vars qw($VERSION $AUTOLOAD);
use Carp;

$VERSION = '0.29';

my @DEFAULT_ENGINES = qw(
			 Finance::QuoteHist::Yahoo
			 Finance::QuoteHist::WallStreetCity
			 Finance::QuoteHist::SiliconInvestor
			);

sub new {
  my $that  = shift;
  my $class = ref($that) || $that;
  my %parms = @_;
  if (!$parms{lineup}) {
    $parms{lineup} = [@DEFAULT_ENGINES];
  }
  elsif (! ref $parms{lineup}) {
    $parms{lineup} = [$parms{lineup}];
  }
  elsif (ref $parms{lineup} ne 'ARRAY') {
    croak "Lineup must be passed as an array ref or single-entry string\n";
  }

  # Instantiate the first, pass the rest as champions to the first
  my $first = shift @{$parms{lineup}};

  eval "require $first;";
  croak $@ if $@;

  my $self = $first->new(%parms);

  $self;
}

1;
__END__

=head1 NAME

Finance::QuoteHist - Perl module for fetching historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist;
  $q = new Finance::QuoteHist
     (
      symbols    => [qw(IBM UPS AMZN)],
      start_date => '01/01/1999',
      end_date   => 'today',      
     );

  # Adjusted values
  foreach $row ($q->quote_get()) {
    ($symbol, $date, $open, $high, $low, $close, $volume) = @$row;
    ...
  }

  # Non adjusted values
  $q->adjusted(0);
  foreach $row ($q->quotes()) {
     ($symbol, $date, $open, $high, $low, $close, $volume, $adj_close) = @$row;
  }

  # Splits
  foreach $row ($q->splits()) {
     ($symbol, $date, $post, $pre) = @$row;
  }

  # Dividends
  foreach $row ($q->dividends()) {
     ($symbol, $date, $dividend) = @$row;
  }

  # Culprit
  $fetch_class = $q->quote_source('IBM');

=head1 DESCRIPTION

Finance::QuoteHist is a top level interface for fetching historical
stock quotes from the web.

It is actually a front end to modules based on
Finance::QuoteHist::Generic, the main difference being that it has a
default I<lineup> of web sites from which to attempt quote retrieval.

Unless otherwise defined via the I<lineup> attribute, this module will
select a I<lineup> for you, the default being:

    Finance::QutoeHist::Yahoo
    Finance::QuoteHist::WallStreetCity
    Finance::QuoteHist::SiliconInvestor

Once instantiated, this module behaves identically to the first module
in the I<lineup>, sharing all of that module's methods.

Most queries will likely be handled by the first module in the
lineup. If the site is down for some reason, or perhaps that site does
not provide quotes for defunct ticker symbols, then the other sites in
the lineup will be attempted.

See L<Finance::QuoteHist::Generic(3)> for gory details on all of the
parameters and methods this module accepts. The basic interface is
noted below.

=head1 METHODS

The basic user interface consists of several methods, as seen in the
example above. Those methods are:

=over

=item quotes()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Symbol>, B<Date>,
B<Open>, B<High>, B<Low>, B<Close>, and B<Volume> for that
date. Optionally, if non-adjusted values were requested, their will be
an extra element at the end of the row for the B<Adjusted> closing
price.

=item dividends()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Date> and amount
of the B<Dividend>, in that order.

=item splits()

Returns a list of rows (or a reference to an array containing those
rows, if in scalar context). Each row contains the B<Date>, B<Post>
split shares, and B<Pre> split shares, in that order.

=item quote_source($ticker)

=item dividend_source($ticker)

=item split_source($ticker)

Each of these methods displays which site-specific class actually
retrieved the information, if any, for a particular ticker symbol.

=item adjusted($boolean)

Sets whether adjusted or non-adjusted quotes are desired. Quotes are
pre-adjusted by default.

=back

=head1 DISCLAIMER

The data returned from these modules is in no way guaranteed, nor are
the developers responsible in any way for how this data (or lack
thereof) is used. The interface is based on URLs and page layouts that
might change at any time. Even though these modules are designed to be
adaptive under these circumstances, they will at some point probably
be unable to retrieve data unless fixed or provided with new
parameters. Furthermore, the data from these web sites is usually not
even guaranteed by the web sites themselves, and oftentimes is
acquired elsewhere. See the documentation for each site-specific
module for more information regarding the disclaimer for that site.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000-2002 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist::Yahoo(3),
Finance::QuoteHist::WallStreetCity(3),
Finance::QuoteHist::SiliconInvestor(3), perl(1).

=cut
