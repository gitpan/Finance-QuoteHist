use ExtUtils::MakeMaker;

$VERSION = 0.22;

WriteMakefile(
	      NAME      => 'Finance-QuoteHist',
	      VERSION   => $VERSION,
              PREREQ_PM => {
			    LWP::UserAgent     => 0,
			    HTTP::Request      => 0,
			    HTML::TableExtract => 0,
			    Date::Manip        => 0,
			   },
	     );
