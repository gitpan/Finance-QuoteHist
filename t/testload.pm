package testload;

use strict;
use Test::More;
use File::Spec;

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

1;
