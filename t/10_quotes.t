use strict;
use lib './lib';

my $tcount;
BEGIN { $tcount = 81 }
use Test::More tests => $tcount;

use FindBin;
use lib $FindBin::RealBin;
use testload;

use Finance::QuoteHist;

SKIP: {
  my($label, $q, @rows);
  $label = "direct quotes";
  skip("quotes (no connect)", $tcount) unless network_okay();
  $q = new_quotehist($Qsym, $Qstart, $Qend);
  @rows = $q->quotes;
  cmp_ok(scalar @Quotes, '==', scalar @rows, "$label (rows)");
  foreach (0 .. $#rows) {
    cmp_ok(join(':', @{$rows[$_]}), 'eq', $Quotes[$_], "$label (row content)");
  }
}
