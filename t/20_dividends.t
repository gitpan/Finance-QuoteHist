use strict;
use lib './lib';
use Test::More tests => 18;

use FindBin;
use lib $FindBin::RealBin;
use testload;

use Finance::QuoteHist;

my($label, $q, @rows);

$label = "filtered dividends";
$q = Finance::QuoteHist->new(
			     symbols    => $Ssym,
			     start_date => $Sstart,
			     end_date   => $Send,
                             parse_mode => 'html',
			    );
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
$q = Finance::QuoteHist->new(
			     symbols    => $Dsym,
			     start_date => $Dstart,
			     end_date   => $Dend,
			    );
@rows = $q->dividends;
cmp_ok(scalar @Dividends, '==', scalar @rows, "$label (rows)");
foreach (0 .. $#rows) {
  my @entry = split(/:/, $Dividends[$_]);
  cmp_ok($rows[$_][0], 'eq', $entry[0], "$label (date)");
  cmp_ok($rows[$_][1], 'eq', $entry[1], "$label (value)");
}
