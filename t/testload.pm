package testload;

use strict;
use Test::More;
use File::Spec;
use LWP::UserAgent;
use HTTP::Request;

use vars qw( @ISA @EXPORT $Dat_Dir
             @Quotes    $Qsym $Qstart $Qend
             @Dividends $Dsym $Dstart $Dend
             @Splits    $Ssym $Sstart $Send
             $CSV
           );

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
             $Dat_Dir
             @Quotes    $Qsym $Qstart $Qend
             @Dividends $Dsym $Dstart $Dend
             @Splits    $Ssym $Sstart $Send
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
my $dividend_file = "$Dat_Dir/dividends.dat";
my $split_file    = "$Dat_Dir/splits.dat";
my $csv_file      = "$Dat_Dir/csv.dat";

my $Network_Up;

foreach ($quote_file, $dividend_file, $split_file) {
  -f or die "$_ not found.\n";
}

open(F, "<$quote_file") or die "Problem reading $quote_file : $!\n";
@Quotes = <F>;
chomp @Quotes;
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

sub network_okay {
  if (! defined $Network_Up) {
    my %ua_parms;
    if ($ENV{HTTP_PROXY}) {
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
  Finance::QuoteHist->new(
    symbols    => $symbols,
    start_date => $start_date,
    end_date   => $end_date,
    auto_proxy => 1,
    debug      => 1,
    %parms,
  );
}

1;
