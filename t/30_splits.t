use strict;
use lib './lib';

my $tcount;
BEGIN { $tcount = 2 }
use Test::More tests => $tcount;

use FindBin;
use lib $FindBin::RealBin;
use testload;

use Finance::QuoteHist;

SKIP: {
  skip("splits (no connect)", $tcount) unless network_okay();
  my($label, $q, @rows);
  $label = "filtered splits";
  $q = new_quotehist($Ssym, $Sstart, $Send);
  @rows = $q->splits;
  cmp_ok(scalar @Splits, '==', scalar @rows, "$label (rows)");
  foreach (0 .. $#rows) {
    cmp_ok(join(':', @{$rows[$_]}), 'eq', $Splits[$_], "$label (row content)");
  }
}
