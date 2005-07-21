use strict;
use lib './lib';
use Test::More tests => 81;

use FindBin;
use lib $FindBin::RealBin;
use testload;

use Finance::QuoteHist;

my($label, $q, @rows);

$label = "direct quotes";
$q = Finance::QuoteHist->new(
			     symbols    => $Qsym,
			     start_date => $Qstart,
			     end_date   => $Qend,
			    );
@rows = $q->quotes;
cmp_ok(scalar @Quotes, '==', scalar @rows, "$label (rows)");
foreach (0 .. $#rows) {
  cmp_ok(join(':', @{$rows[$_]}), 'eq', $Quotes[$_], "$label (row content)");
}
