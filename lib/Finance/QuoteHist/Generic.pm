package Finance::QuoteHist::Generic;

use strict;
use vars qw($VERSION @ISA);
use Carp;

use LWP::UserAgent;
use HTTP::Request;
@ISA = qw(LWP::UserAgent);

use Date::Manip;
use HTML::TableExtract;

$VERSION = '0.01';

# Column standard.  rows() should return refs to arrays with
# components in the following order:
#
# symbol date open high low close volume
#

###

sub new {
  my $that  = shift;
  my $class = ref($that) || $that;
  my(@pass, %parms, $k, $v);
  while (($k,$v) = splice(@_, 0, 2)) {
    if ($k eq 'start_date' || $k eq 'end_date') {
      my $d = ParseDate($v);
      $d or croak "Could not parse date $d\n";
      $d =~ s/\d\d:.*//;
      $parms{$k} = $d;
    }
    elsif ($k eq 'symbols') {
      ref $v eq 'ARRAY' or croak "Symbol array ref required\n";
      grep($_ = uc $_, @$v);
      $parms{$k} = $v;
    }
    elsif ($k eq 'lineup') {
      ref $v eq 'ARRAY' or croak "Lineup array ref required\n";
      $parms{$k} = $v;
    }
    elsif ($k eq 'column_labels') {
      $parms{$k} = $v;
    }
    elsif ($k eq 'verbose' || $k eq 'zthresh' ||
	   $k eq 'attempts' || $k eq 'reverse') {
      $parms{$k} = $v;
    }
    else {
      push(@pass, $k, $v);
    }
  }
  $parms{start_date}    or croak "Start date required\n";
  $parms{end_date}      or croak "End date required\n";
  $parms{symbols}       or croak "Symbol list required\n";

  $parms{column_labels} = [qw(Date Open High Low Close Volume)]
    unless $parms{column_labels};

  $parms{lineup} = [] unless $parms{lineup};

  $parms{zthresh}  = 30 unless $parms{zthresh};
  $parms{attempts} = 4  unless $parms{attempts};
  my $self = new LWP::UserAgent @pass;
  bless $self, $class;
  foreach (keys %parms) {
    $self->{$_} = $parms{$_};
  }

  $self;
}

sub fetch {
  my $self = shift;
  my $url  = shift;
  $url or croak "URL required\n";
  my $method = shift;
  $method = $self->method unless $method;
  my $trys = $self->{attempts} - 1;
  my $response = $self->request(new HTTP::Request($method, $url), @_);
  while (! $response->is_success) {
    last unless $trys;
    print STDERR "Bad fetch, trying again...\n" if $self->{verbose};
    $response = $self->request(new HTTP::Request($method, $url), @_);
    --$trys;
  }
  $self->{_lwp_success} = $response->is_success;
  return undef unless $response->is_success;
  print STDERR "Fetch complete.\n" if $self->{verbose};
  $response->content;
}

sub getquotes {
  my $self = shift;
  my(@rows, @fetch_rows);
  $self->{_empty_fetch} = {};
  foreach my $s ($self->symbols) {
    foreach ($self->urls($s)) {
      if ($self->{_empty_fetch}{$s}) {
	print STDERR "Skipping $s for now, empty fetch :-(\n"
	  if $self->{verbose};
	last;
      }
      last if $self->{_empty_fetch}{$s};
      print STDERR "Processing $_\n" if $self->{verbose};
      my @r = $self->applicable_rows($self->fetch($_));
      my $trys = 3;
      while (!@r && $trys && $self->{_lwp_success}) {
	print STDERR "Trying again due to no rows...\n" if $self->{verbose};
	@r = $self->applicable_rows($self->fetch($_));
	--$trys;
      }
      $self->{_zcount} = $self->{_hcount} = 0;
      @r = reverse @r if $self->{reverse};
      foreach (@r) {
	foreach (@$_) {
	  s%^\s*N/A\s*$%%;
	}
	my $q = $_->[5];
	$q =~ s/[\$,]//g;
	if ($q) { ++$self->{_hcount} }
	else { ++$self->{_zcount} };
      }
      my $pct;
      if ($self->{_hcount}) {
	$pct = 100*$self->{_zcount}/($self->{_zcount}+$self->{_hcount});
      }
      else {
	$pct = 100;
      }
      if (!$trys || $pct >= $self->{zthresh}) {
	++$self->{_empty_fetch}{$s};
      }
      push(@rows, map([$s, @$_], @r));
    }
  }
  # Check for bad fetches.  If we failed on some symbols, punt
  # them to our champion class.
  if (%{$self->{_empty_fetch}}) {
    my @bad_symbols = sort keys %{$self->{_empty_fetch}};
    if (!$self->{_champion}) {
      $self->{_champion} = $self->_summon_champion(@bad_symbols);
    }
    if ($self->{_champion}) {
      if ($self->{verbose}) {
	print STDERR "Bad fetch for ", join(',', @bad_symbols), " booting to ",
	ref $self->{_champion}, "\n";
      }
      push(@rows, $self->{_champion}->getquotes(@_));
    }
  }
  @rows;
}

sub date_in_range {
  my $self = shift;
  my $date = shift;
  $date = ParseDate($date) or return undef;
  $date =~ s/\d\d:.*//;
  $date ge $self->{start_date} && $date le $self->{end_date};
}

###

sub table_extract { shift->{_table_extract} }

sub rows {
  my $self = shift;
  my $html_string  = shift;
  return () unless $html_string;

  my $te = new HTML::TableExtract(
				  headers => [$self->column_labels],
				  automap => 1,
				 );
  $te->parse($html_string);
  my @rows = $te->rows;
  # Prep the rows
  foreach (@rows) {
    foreach (@$_) {
      # Zap leading and trailing white space
      s/^\s+//;
      s/\s+$//;
    }
  }
  # Pass only rows with a valid date
  grep(ParseDate($_->[0]), @rows);
}

sub applicable_rows {
  my $self = shift;
  my @r = $self->rows(@_);
  print STDERR "Got ",scalar @r, " raw rows, " if $self->{verbose};
  @r = grep($self->date_in_range($_->[0]), @r);
  print STDERR "trimmed to ",scalar @r, " rows\n" if $self->{verbose};
  @r;
}

###

sub mydates {
  my $self = shift;
  $self->dates($self->{start_date}, $self->{end_date});
}

sub dates {
  my($self, $sdate, $edate) = @_;
  $sdate && $edate or croak "Start date and end date strings required\n";
  my $sd = ParseDate($sdate) or croak "Could not parse start date $sdate\n";
  my $ed = ParseDate($edate) or croak "Could not parse end date $edate\n";
  ($sd, $ed) = sort($sd, $ed);
  $sd =~ s/\d\d:.*//;
  $ed =~ s/\d\d:.*//;
  my @dates;
  push(@dates, $sd) if Date_IsWorkDay($sd);
  my $cd = Date_NextWorkDay($sd, 1);
  $cd =~ s/\d\d:.*//;
  while ($cd <= $ed) {
    push(@dates, $cd);
    $cd = Date_NextWorkDay($cd);
    $cd =~ s/\d\d:.*//;
  }
  @dates;
}

sub symbols {
  my $self = shift;
  sort @{$self->{symbols}};
}

sub column_labels {
  my $self = shift;
  @{$self->{column_labels}};
}

sub successors {
  my $self = shift;
  @{$self->{successors}};
}

###

# Stubs, to be defined by an instance for a particular quote
# source.

sub urls {
  my $self = shift;
  undef;
}

sub method {
  'GET';
}

###

sub _summon_champion {
  # Instantiate the next class in line if this
  # class failed in fetching any quotes.  Make sure and
  # pass along the remaining champions to the new champion.
  my($self, @bad_symbols) = @_;
  return undef unless ref $self->{lineup} && @{$self->{lineup}};
  my $champ_class = shift @{$self->{lineup}};
  print STDERR "Loading $champ_class\n" if $self->{verbose};
  eval "require $champ_class;";
  die $@ if $@;
  my $champion;
  eval "\$champion = new $champ_class  (
	 symbols    => [\@bad_symbols],
	 start_date => \$self->{start_date},
	 end_date   => \$self->{end_date},
         verbose    => \$self->{verbose},
         lineup     => \$self->{lineup},
	);";
  die $@ if $@;
  $champion;
}

###

sub ymd {
  my $self = shift;
  shift =~ /^\s*(\d{4})(\d{2})(\d{2})/;
}
sub year {
  (shift->ymd(shift))[0];
}
sub month {
  (shift->ymd(shift))[1];
}
sub day {
  (shift->ymd(shift))[2];
}

1;
__END__

=head1 NAME

Finance::QuoteHist::Generic - Perl extension for retrieving historical
stock quotes.

=head1 SYNOPSIS

  package Finance::QuoteHist::MyFavoriteSite;
  use strict;
  use vars qw(@ISA);
  use Finance::QuoteHist::Generic;
  @ISA = qw(Finance::QuoteHist::Generic);

  sub urls {
    # This method would return the set of URLs necessary
    # to extract the quotes from this particular site given
    # the list of symbols and date range provided during
    # instantiation. See Finance::QuoteHist::MotleyFool
    # for an example of how to do this.
  }

=head1 DESCRIPTION

This is the base class for retrieving historical stock quotes. It
is a sub class of LWP::UserAgent, and expects the raw data to be
in HTML form, which in turn gets passed through HTML::TableExtract.

In order to actually retrieve historical stock quotes, this class
should be subclassed and tailored to a particular web site.  In
particular, the C<urls()> method should be overridden, and provide
however many URLs are necessary to retrieve the data over a list
of symbols within the givin date range.  Different sites have
different limitations on how many quotes are returned for each
query. See Finance::QuoteHist::MotleyFool and Finance::QuoteHist::FinancialWeb
for some examples of how to do this.

=head1 METHODS

=over

=item new()

Returns a new Finance::QuoteHist::Generic object. Unless noted
below, attributes are passed along to the LWP::UserAgent constructor.
Attributes specific to this class are:

=over

=item start_date

=item end_date

Specify the date range from which you would like historical quotes.
These dates get parsed by the C<ParseDate()> method in Date::Manip,
so see L<Date::Manip(3)> for more information on valid date strings.
They are quite flexible, and include such strings as 'today'.

=item symbols

Passed as an array reference, indicates which ticker symbols to
include in the search for historical quotes.

=item column_labels

Strings indicating which columns to extract from the resulting
HTML document. These get passed as I<Headers> to the HTML::TableExtract
object, so see L<HTML::TableExtract(3)> for more details on what
they actually do.  They eventually end up as unanchored, case-insensitive
regular expressions, so regexp characters are acceptable. The default
column_labels are B<Date>, B<Open>, B<High>, B<Low>, B<Close>, and B<Volume>.
These are generally sufficient for most historical quote sites, and
through the magic of HTML::TableExtract, the resulting rows are always
returned in the same order these labels are provided, regardless of
which site harbored the data.

=item reverse

Simple flag that indicates whether each batch of rows from each URL
provided in urls() should be reversed from top to bottom.  Some
sites present historical quotes with the newest quotes on the top.
Since the rows from each URL are eventually catenated, if the overall
order of your rows is important you might want to pay attention
to this flag.  If the overal order is not that important, then ignore
this flag.  Typically, site-specific sub classes of this module will
take care of setting this appropriately.  The default is 0.

=item attempts

This flag sets how persistently the module trys to retrieve the
quotes.  There are two places this manifests itself.  First, if
there are what appear to be network errors, this many network
connections are attempted for that URL.  Secondly, if a document
was successfully retrieved, but it contained no quotes, this
number of attempts are made to retrieve a document with data.
Sometimes sites will report a temporary internal error via HTML,
and if it is truly transitory this will usually get around it.
The default is 3.

=item lineup

Passed as an array reference, this list indicates which
Finance::QuoteHist::Generic sub classes should be invoked
in the event this class fails in its attempt to retrieve
historical quotes.  In the event of failure, the first class
in this list is invoked with the same parameters as the original
class, and the remaining classes are passed
as the lineup to the new class. This sets up a simple daisy
chain of redundancy in the event a particular site is hosed.
See L<Finance::QuoteHist> to see an example of how this is
done in a top level invocation of these modules.  This
list is empty by default.

=item verbose

When set, many status messages are printed to STDERR indicating
progression through URLs and lineup invocations.

=back

=item urls()

This method should be overidden in a subclass. By default it
does nothing. When overidden, it should return the list of
URLs necessary to retrieve all historical quotes from a
particular site for the symbols and date ranges provided upon
instantiation of the object.

=item getrows()

Returns all historical quotes for the date range and symbols
provided upon instantiation. Quotes are returned as references
to arrays, each of which is composed of values for the
headers supplied with the column_labels parameter to new().
Currently these are not cached, so each time you invoke this
method, all network transactions and HTML extractions will
be repeated.

=back

Most of the methods below are utilized during a call to getrows().
If all you want to do is grab historical quotes, then these
methods are probably of limited use, but they are included here
just in case.

=over

=item fetch($url)

Returns the web page located at C<$url>.

=item rows($html_string)

Given an HTML string, extracts the rows from tables that have
headers matching the column labels provided upon instantiation
of the object.

=item applicable_rows(@rows)

Given a list of rows, return those rows that fit the criterion
of the search, such as being within the target date range.

=item date_in_range($date)

Given a date string, test whether it is within the range
specified by I<start_date> and I<end_date> during object instantiation.

=item dates($start_date, $end_date)

Returns a list of business days between and including the provided
boundary dates.

=item mydates()

Invokes dates() on the start date and end date provided to new()
during object instantiation.

=back

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

Finance::QuoteHist(3), HTML::TableExtract(3), Date::Manip(3), perl(1).

=cut
