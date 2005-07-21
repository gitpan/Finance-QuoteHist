use strict;
use lib './lib';
use Test::More tests => 2;

use FindBin;
use lib $FindBin::RealBin;
use testload;

use Finance::QuoteHist;

my($label, $q, @rows);

$label = "filtered splits";
$q = Finance::QuoteHist->new(
			     symbols    => $Ssym,
			     start_date => $Sstart,
			     end_date   => $Send,
			    );
@rows = $q->splits;
cmp_ok(scalar @Splits, '==', scalar @rows, "$label (rows)");
foreach (0 .. $#rows) {
  cmp_ok(join(':', @{$rows[$_]}), 'eq', $Splits[$_], "$label (row content)");
}
