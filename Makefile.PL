use ExtUtils::MakeMaker;

eval "use Text::CSV_XS";
if ($@) {
  print STDERR <<__MSG;
Note: This is not required, but installing Text::CSV_XS on your system
      will speed up the parsing of quote data in CSV format. A C
      compiler is necessary, however. In the meantime we will use
      Text::CSV_PP.
__MSG
}

WriteMakefile(
  NAME          => 'Finance-QuoteHist',
  VERSION_FROM  => 'lib/Finance/QuoteHist.pm',
  PREREQ_PM => {
    LWP::UserAgent     => 0,
    HTTP::Request      => 0,
    HTML::TableExtract => 2.03,
    Text::CSV_PP       => 0,
  },
);
