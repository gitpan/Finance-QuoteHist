use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME          => 'Finance-QuoteHist',
	      VERSION_FROM  => 'lib/Finance/QuoteHist.pm',
              PREREQ_PM => {
			    LWP::UserAgent     => 0,
			    HTTP::Request      => 0,
			    HTML::TableExtract => 0,
			    Date::Manip        => 0,
			   },
	     );
