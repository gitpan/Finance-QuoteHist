# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Finance::QuoteHist;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$pass = 1;
$q = Finance::QuoteHist->new(
				symbols    => [ '^DJA' ],
				start_date => '11/01/1997',
				end_date   => '02/28/1998',
			    );
@rows = $q->quotes;
chomp($tcount = <DATA>);
@trows = <DATA>;
chomp @trows;
$pass = 0 unless $tcount == $#rows;
foreach (0 .. $#rows) {
   if (join(':', @{$rows[$_]}) ne $trows[$_]) {
      $pass = 0;
      last;
   }
}
print $pass ? "ok" : "not ok";
print " 2 (basic fetch)\n";

__END__
79
^DJA:1997/11/03:2484.6000:2521.1000:2461.1000:2509.0000:0
^DJA:1997/11/04:2494.5000:2530.4000:2478.2000:2510.8000:0
^DJA:1997/11/05:2504.2000:2541.4000:2489.6000:2512.4000:0
^DJA:1997/11/06:2501.6000:2530.4000:2481.8000:2508.9000:0
^DJA:1997/11/07:2483.4000:2501.3000:2446.0000:2483.0000:0
^DJA:1997/11/10:2482.7000:2511.8000:2455.6000:2469.7000:0
^DJA:1997/11/11:2480.6000:2497.8000:2452.8000:2474.6000:0
^DJA:1997/11/12:2460.9000:2480.5000:2417.7000:2430.7000:0
^DJA:1997/11/13:2444.5000:2466.9000:2401.0000:2441.3000:0
^DJA:1997/11/14:2439.2000:2488.0000:2425.6000:2468.3000:0
^DJA:1997/11/17:2501.5000:2532.7000:2476.2000:2508.6000:0
^DJA:1997/11/18:2510.1000:2527.9000:2473.5000:2487.7000:0
^DJA:1997/11/19:2487.8000:2520.1000:2465.4000:2500.6000:0
^DJA:1997/11/20:2522.1000:2561.8000:2501.9000:2544.3000:0
^DJA:1997/11/21:2552.5000:2577.2000:2520.6000:2559.0000:0
^DJA:1997/11/24:2545.1000:2564.4000:2510.2000:2527.9000:0
^DJA:1997/11/25:2531.5000:2568.7000:2511.9000:2542.8000:0
^DJA:1997/11/26:2545.9000:2573.8000:2527.9000:2546.5000:0
^DJA:1997/11/28:2559.6000:2570.5000:2542.7000:2555.6000:0
^DJA:1997/12/01:2592.4000:2625.9000:2554.7000:2612.7000:0
^DJA:1997/12/02:2618.7000:2640.1000:2588.4000:2612.5000:0
^DJA:1997/12/03:2599.5000:2640.5000:2576.6000:2613.8000:0
^DJA:1997/12/04:2623.8000:2654.3000:2596.3000:2620.3000:0
^DJA:1997/12/05:2634.6000:2660.8000:2597.5000:2641.1000:0
^DJA:1997/12/08:2646.4000:2669.3000:2618.9000:2643.4000:0
^DJA:1997/12/09:2631.3000:2655.3000:2607.7000:2631.1000:0
^DJA:1997/12/10:2622.7000:2642.5000:2587.0000:2618.3000:0
^DJA:1997/12/11:2583.9000:2614.5000:2542.2000:2571.7000:0
^DJA:1997/12/12:2583.4000:2612.3000:2545.0000:2571.7000:0
^DJA:1997/12/15:2588.6000:2621.7000:2563.5000:2598.8000:0
^DJA:1997/12/16:2614.7000:2638.2000:2580.4000:2604.4000:0
^DJA:1997/12/17:2603.3000:2637.1000:2576.3000:2599.2000:0
^DJA:1997/12/18:2581.9000:2612.3000:2542.4000:2563.8000:0
^DJA:1997/12/19:2502.3000:2572.1000:2478.3000:2539.9000:0
^DJA:1997/12/22:2552.1000:2583.9000:2521.6000:2557.2000:0
^DJA:1997/12/23:2545.2000:2577.4000:2515.4000:2529.9000:0
^DJA:1997/12/24:2531.9000:2549.8000:2505.6000:2517.8000:0
^DJA:1997/12/26:2525.0000:2541.1000:2508.0000:2520.9000:0
^DJA:1997/12/29:2545.2000:2565.2000:2522.0000:2548.0000:0
^DJA:1997/12/30:2570.9000:2612.0000:2545.6000:2597.3000:0
^DJA:1997/12/31:2602.5000:2632.2000:2576.3000:2607.4000:0
^DJA:1998/01/02:2603.3000:2630.6000:2579.5000:2611.2000:0
^DJA:1998/01/05:2623.0000:2646.0000:2581.3000:2613.8000:0
^DJA:1998/01/06:2607.9000:2631.3000:2572.0000:2600.8000:0
^DJA:1998/01/07:2584.3000:2624.3000:2556.3000:2609.0000:0
^DJA:1998/01/08:2588.9000:2626.5000:2559.3000:2584.8000:0
^DJA:1998/01/09:2569.3000:2595.1000:2499.1000:2518.4000:0
^DJA:1998/01/12:2515.9000:2561.9000:2464.4000:2544.2000:0
^DJA:1998/01/13:2550.2000:2583.0000:2529.7000:2565.4000:0
^DJA:1998/01/14:2559.0000:2587.4000:2536.9000:2568.5000:0
^DJA:1998/01/15:2559.3000:2583.5000:2532.6000:2549.3000:0
^DJA:1998/01/16:2575.4000:2604.9000:2549.0000:2575.1000:0
^DJA:1998/01/20:2590.5000:2630.3000:2565.3000:2617.1000:0
^DJA:1998/01/21:2605.0000:2632.9000:2567.1000:2597.6000:0
^DJA:1998/01/22:2587.6000:2619.4000:2551.8000:2580.6000:0
^DJA:1998/01/23:2564.3000:2604.8000:2530.3000:2556.9000:0
^DJA:1998/01/26:2578.1000:2594.2000:2534.7000:2557.8000:0
^DJA:1998/01/27:2571.5000:2598.1000:2533.1000:2570.4000:0
^DJA:1998/01/28:2588.5000:2629.1000:2559.7000:2608.2000:0
^DJA:1998/01/29:2621.2000:2654.4000:2589.0000:2625.0000:0
^DJA:1998/01/30:2623.0000:2641.1000:2587.9000:2604.8000:0
^DJA:1998/02/02:2648.1000:2673.9000:2620.5000:2654.8000:0
^DJA:1998/02/03:2650.7000:2682.1000:2629.8000:2670.1000:0
^DJA:1998/02/04:2659.0000:2688.7000:2635.8000:2664.4000:0
^DJA:1998/02/05:2663.8000:2695.0000:2636.5000:2661.5000:0
^DJA:1998/02/06:2677.5000:2704.7000:2655.2000:2684.8000:0
^DJA:1998/02/09:2688.8000:2715.9000:2662.5000:2694.8000:0
^DJA:1998/02/10:2714.3000:2746.2000:2681.6000:2723.6000:0
^DJA:1998/02/11:2723.3000:2748.3000:2701.2000:2727.6000:0
^DJA:1998/02/12:2720.8000:2776.1000:2699.7000:2760.2000:0
^DJA:1998/02/13:2755.2000:2781.7000:2723.4000:2750.6000:0
^DJA:1998/02/17:2773.7000:2791.0000:2739.0000:2764.2000:0
^DJA:1998/02/18:2764.7000:2792.7000:2734.8000:2765.8000:0
^DJA:1998/02/19:2746.2000:2775.1000:2725.8000:2743.1000:0
^DJA:1998/02/20:2728.7000:2761.6000:2701.1000:2740.4000:0
^DJA:1998/02/23:2738.5000:2774.9000:2721.0000:2748.3000:0
^DJA:1998/02/24:2726.6000:2759.7000:2701.8000:2721.9000:0
^DJA:1998/02/25:2745.6000:2766.4000:2714.0000:2745.1000:0
^DJA:1998/02/26:2744.5000:2768.2000:2708.5000:2743.9000:0
^DJA:1998/02/27:2745.1000:2772.2000:2715.8000:2746.3000:0
