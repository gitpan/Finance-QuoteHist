package Finance::QuoteHist;

# Simple aggregator for Finance::QuoteHist::Generic instances,
# the primary function of which is to specify the order in which
# to try the modules upon failure.

use strict;
use vars qw($VERSION $AUTOLOAD);
use Carp;

$VERSION = '0.01';

my @DEFAULT_ENGINES = qw(
			 Finance::QuoteHist::MotleyFool
			 Finance::QuoteHist::FinancialWeb
			);

sub new {
  my $that  = shift;
  my $class = ref($that) || $that;
  my(@pass, %parms, $k, $v, $lineup);
  while (($k,$v) = splice(@_, 0, 2)) {
    if ($k eq 'lineup') {
      ref $v or croak "Lineup list must be passed as ref to ARRAY.\n";
      $lineup = $v;
    }
    else {
      push(@pass, $k, $v);
    }
  }

  $lineup = [@DEFAULT_ENGINES] unless $lineup;

  # Instantiate the first, pass the rest as champions to the first
  my $first = shift @$lineup;
  push(@pass, 'lineup', $lineup);

  my $self = {};
  bless $self, $class;

  eval "require $first;";
  croak $@ if $@;
  eval "\$self->{_super} = new $first \@pass;";
  croak $@ if $@;

  $self;
}

sub AUTOLOAD {
  # This class HAS-A instance of the first provided in the lineup,
  # and passes everything to it.
  my $self = shift;
  my $name = $AUTOLOAD;
  $name =~ s/.*:://;
  return if $name =~ /^DESTROY/;
  $self->{_super}->$name(@_);
}

1;
__END__

=head1 NAME

Portfolio::QuoteHist - Perl extension for fetching historical stock quotes.

=head1 SYNOPSIS

  use Finance::QuoteHist;
  $q = new Finance::QuoteHist
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

Finance::QuoteHist is a top level interface for fetching  historical
stock quotes from the web.

It is actually a front end to modules based on Finance::QuoteHist::Generic,
the main difference being that it has a default I<lineup> of
web sites from which to attempt quote retrieval.

Unless otherwise defined via the I<lineup> attribute, this module will
select a I<lineup> for you, the default being:

    Finance::QuoteHist::MotleyFool
    Finance::QuoteHist::FinancialWeb

Once instantiated, this module behaves identically to the first module
in the I<lineup>, sharing all of that module's methods.

One observational note regarding this I<lineup>: it has been the author's
experience that the I<Motley Fool> website tends to have more reliable
data than I<FinancialWeb>, but the I<Motley Fool> does not return quotes
for defunct ticker symbols, whereas I<FinancialWeb> does. This default
lineup is a nice stab at reliability and completeness.

See L<Finance::QuoteHist::Generic(3)> for details on all of the parameters
and methods this module accepts.

=head1 DISCLAIMER

The data returned from these modules is in no way guaranteed, nor
are the developers responsible in any way for how this data
(or lack thereof) is used. The interface is based on URLs and page
layouts that might change at any time. Even though these modules
are designed to be adaptive under these circumstances, they will at
some point probably be unable to retrieve data unless fixed or
provided with new parameters. Furthermore, the data from these web
sites is usually not even guaranteed by the web sites themselves,
and oftentimes is acquired elsewhere. See the documentation for
each site-specific module for more information regarding the
disclaimer for that site.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000 Matthew P. Sisk.
All rights reserved. All wrongs revenged. This program is free
software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist::Generic(3), Finance::QuoteHist::MotleyFool(3),
Finance::QuoteHist::FinancialWeb(3), perl(1).

=cut
