use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      NAME	   => 'Finance-QuoteHist',
	      VERSION_FROM => 'lib/Finance/QuoteHist/Generic.pm',
              PREREQ_PM    => {
			       LWP::UserAgent     => 0,
			       HTTP::Request      => 0,
			       HTML::TableExtract => 0,
			       Date::Manip        => 0,
			      },
	     );
