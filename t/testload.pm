package testload;

use strict;
use Test::More;
use File::Spec;
use LWP::UserAgent;
use HTTP::Request;

use Finance::QuoteHist;

use vars qw( @ISA @EXPORT $Dat_Dir
             @Quotes    $Qsym $Qstart $Qend
             @Dividends $Dsym $Dstart $Dend
             @Splits    $Ssym $Sstart $Send
             @Quotes_W @Quotes_M $Q_Grain
             $CSV
           );

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
             $Dat_Dir
             @Quotes    $Qsym $Qstart $Qend
             @Dividends $Dsym $Dstart $Dend
             @Splits    $Ssym $Sstart $Send
             @Quotes_W @Quotes_M $Q_Grain
             $CSV
             network_okay new_quotehist
            );

my $base_dir;
BEGIN {
  my $pkg = __PACKAGE__;
  $pkg =~ s%::%/%g;
  $pkg .= '.pm';
  my @parts = File::Spec->splitpath(File::Spec->canonpath($INC{$pkg}));
  $parts[-1] = '';
  $base_dir = File::Spec->catpath(@parts);
}
$Dat_Dir = $base_dir;

my $quote_file    = "$Dat_Dir/quotes.dat";
my $quote_w_file  = "$Dat_Dir/quotes_w.dat";
my $quote_m_file  = "$Dat_Dir/quotes_m.dat";
my $dividend_file = "$Dat_Dir/dividends.dat";
my $split_file    = "$Dat_Dir/splits.dat";
my $csv_file      = "$Dat_Dir/csv.dat";

-f or die "$_ not found.\n"
  foreach ($quote_file, $quote_w_file, $quote_m_file,
           $dividend_file, $split_file);

open(F, "<$quote_file") or die "Problem reading $quote_file : $!\n";
@Quotes = <F>;
chomp @Quotes;
close(F);

open(F, "<$quote_w_file") or die "Problem reading $quote_w_file : $!\n";
@Quotes_W = <F>;
chomp @Quotes_W;
close(F);

open(F, "<$quote_m_file") or die "Problem reading $quote_m_file : $!\n";
@Quotes_M = <F>;
chomp @Quotes_M;
close(F);

open(F, "<$dividend_file") or die "Problem reading $dividend_file : $!\n";
@Dividends = <F>;
chomp @Dividends;
close(F);

open(F, "<$split_file") or die "Problem reading $split_file : $!\n";
@Splits = <F>;
chomp @Splits;
close(F);

open(F, "<$csv_file") or die "Problem reading $csv_file : $!\n";
{ local $/; $CSV = <F> }
close(F);

($Qsym, $Qstart, $Qend) = split(',', shift @Quotes);
($Dsym, $Dstart, $Dend) = split(',', shift @Dividends);
($Ssym, $Sstart, $Send) = split(',', shift @Splits);

# currently we share the same symbol, start, end as @Quotes
shift @Quotes_W;
shift @Quotes_M;

my $Network_Up;

sub network_okay {
  if (! defined $Network_Up) {
    my %ua_parms;
    if ($ENV{http_proxy}) {
      $ua_parms{env_proxy} = 1;
    }
    my $ua = LWP::UserAgent->new(%ua_parms)
      or die "Problem creating user agent\n";
    my $request = HTTP::Request->new('GET', 'http://finance.yahoo.com')
      or die "Problem creating http request object\n";
    my $response = $ua->request($request, @_);
    $Network_Up = $response->is_success;
    if (!$Network_Up) {
      print STDERR "Problem with net fetch: ", $response->status_line, "\n";
    }
  }
  $Network_Up;
}

sub new_quotehist {
  my($symbols, $start_date, $end_date, %parms) = @_;
  my $class = $parms{class} || 'Finance::QuoteHist';
  delete $parms{class};
  $class->new(
    symbols    => $symbols,
    start_date => $start_date,
    end_date   => $end_date,
    auto_proxy => 1,
    %parms,
  );
}

1;
