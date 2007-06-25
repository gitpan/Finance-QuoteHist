use strict;
use lib './lib';

my $tcount;
BEGIN { $tcount = 104 }
use Test::More tests => $tcount;

use FindBin;
use lib $FindBin::RealBin;
use testload;

SKIP: {
  skip("quotes (no connect)", $tcount) unless network_okay();
  my @basis = ($Qsym, $Qstart, $Qend);
  my %parms;
  quote_cmp(@basis, "direct quotes (daily)",   \@Quotes);
  $parms{granularity} = 'weekly';
  quote_cmp(@basis, "direct quotes (weekly)",  \@Quotes_W, %parms);
  $parms{granularity} = 'monthly';
  quote_cmp(@basis, "direct quotes (monthly)", \@Quotes_M, %parms);
}

sub quote_cmp {
  @_ >= 5 or die "Problem with args\n";
  my($symbol, $start_date, $end_date, $label, $quotes, %parms) = @_;
  my $q = new_quotehist($symbol, $start_date, $end_date, %parms);
  my @rows = $q->quotes;
  cmp_ok(scalar @rows, '==', scalar @$quotes, "$label (rows)");
  foreach (0 .. $#rows) {
    cmp_ok(join(':', @{$rows[$_]}), 'eq', $quotes->[$_],
           "$label (row content)");
  }
}
