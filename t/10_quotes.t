use strict;

my $tcount;
BEGIN { $tcount = 28 }
use Test::More tests => $tcount;

use FindBin;
use lib $FindBin::RealBin;
use testload;

SKIP: {
  skip("quotes (no connect)", $tcount) unless network_ok();
  for my $src (sources()) {
    for my $gran (granularities($src)) {
      SKIP: {
        skip("skip developer $src-$gran test", 2)
          unless DEV_TESTS || $src eq 'plain';
        my($m, $sym, $start, $end, $dat) = basis($src, 'quote', $gran);
        next unless $m;
        eval "use $m";
        my %parms = ( class => $m, granularity => $gran );
        quote_cmp(
          $sym, $start, $end,
          "direct quotes ($src:$gran)",
          $dat, %parms
        );
      }
    }
  }
}

sub quote_cmp {
  @_ >= 5 or die "Problem with args\n";
  my($symbol, $start_date, $end_date, $label, $dat, %parms) = @_;
  my $q = new_quotehist($symbol, $start_date, $end_date, %parms);
  my @rows = $q->quotes;
  cmp_ok(scalar @rows, '==', scalar @$dat, "$label (rows)");
  for my $i (0 .. $#rows) {
    # drop volume, too variable for testing
    pop @{$rows[$i]};
    $rows[$i] = join(':', @{$rows[$i]});
  }
  is_deeply(\@rows, $dat, "$label (content)");
}
