use strict;
use lib './lib';

my $tcount;
BEGIN { $tcount = 18 }
use Test::More tests => $tcount;

use FindBin;
use lib $FindBin::RealBin;
use testload;

use Finance::QuoteHist;

SKIP: {
  skip("dividends (no connect)", $tcount) unless network_okay();
  my($label, $q, @rows);
  $label = "filtered dividends";
  $q = new_quotehist($Ssym, $Sstart, $Send, parse_mode => 'html');

  # main query, from which divs should be filtered
  @rows = $q->quotes;
  # retrieve what was filtered
  @rows = $q->dividends;
  cmp_ok(scalar @Dividends, '==', scalar @rows, "$label (rows)");
  foreach (0 .. $#rows) {
    my @entry = split(/:/, $Dividends[$_]);
    cmp_ok($rows[$_][0], 'eq', $entry[0], "$label (date)");
    cmp_ok($rows[$_][1], 'eq', $entry[1], "$label (value)");
  }

  $label = "direct dividends";
  $q = new_quotehist($Dsym, $Dstart, $Dend);
  @rows = $q->dividends;
  cmp_ok(scalar @Dividends, '==', scalar @rows, "$label (rows)");
  foreach (0 .. $#rows) {
    my @entry = split(/:/, $Dividends[$_]);
    cmp_ok($rows[$_][0], 'eq', $entry[0], "$label (date)");
    cmp_ok($rows[$_][1], 'eq', $entry[1], "$label (value)");
  }
}
