package Finance::QuoteHist::Generic;

use strict;
use vars qw($VERSION @ISA);
use Carp;

use LWP::UserAgent;

use HTTP::Request;
use Date::Manip;
use HTML::TableExtract;

$VERSION = '0.21';

my @Default_Quote_Labels    = qw( Date Open High Low Close Volume );
my @Default_Dividend_Labels = qw( Date Div );
my @Default_Split_Labels    = qw( Date Post Pre );

my @Scalar_Flags = qw(
		      verbose
		      quiet
		      zthresh
		      quote_precision
		      ratio_precision
		      attempts
		      reverse
		      adjusted
		      has_non_adjusted
		      debug
		     );
my $SF_pat = join('|', @Scalar_Flags);

# (csv_column_labels are only necessary if there is some expectation
# of CSV data not having labels in the first line)
my @Array_Flags = qw(
		     symbols
		     lineup
		    );
my $AF_pat = join('|', @Array_Flags);

sub new {
  my $that  = shift;
  my $class = ref($that) || $that;
  my(@pass, %parms, $k, $v);
  while (($k,$v) = splice(@_, 0, 2)) {
    if ($k eq 'start_date' || $k eq 'end_date') {
      my $d = ParseDate($v);
      $d or croak "Could not parse date $d\n";
      $d =~ s/\d\d:.*//;
      $parms{$k} = $d;
    }
    elsif ($k =~ /^$AF_pat$/o) {
      if (ref $v eq 'ARRAY') {
	$parms{$k} = $v;
      }
      elsif (ref $v) {
	croak "$1 must be passed as an array ref or single-entry string\n";
      }
      else {
	$parms{$k} = [$v];
      }
    }
    elsif ($k =~ /^$SF_pat$/o) {
      $parms{$k} = $v;
    }
  }
  $parms{start_date} or croak "Start date required\n";
  $parms{end_date}   or croak "End date required\n";
  $parms{symbols}    or croak "Symbol list required\n";

  my $start_date = $parms{start_date}; delete $parms{start_date};
  my $end_date   = $parms{end_date};   delete $parms{end_date};
  my $symbols    = $parms{symbols};    delete $parms{symbols};

  # Defaults
  $parms{zthresh}          = 30 unless $parms{zthresh};
  $parms{attempts}         = 3  unless $parms{attempts};
  $parms{adjusted}         = 1  unless defined $parms{adjusted};
  $parms{has_non_adjusted} = 0  unless defined $parms{has_non_adjusted};
  $parms{quote_precision}  = 4  unless defined $parms{quote_precision};
  $parms{ratio_precision}  = 0  unless defined $parms{ratio_precision};

  my $self = \%parms;
  bless $self, $class;

  $self->{ua} = new LWP::UserAgent;
  $self->start_date($start_date);
  $self->end_date($end_date);
  $self->symbols(@$symbols);

  # These are used for constructing method names for target types.
  $self->{target_order} = [qw(quote split dividend)];
  grep($self->{targets}{$_} = "${_}s", @{$self->{target_order}});
  
  # Register our parsers. HTML by default.
  $self->parse_method('html', 'html_table_parser');
  $self->parse_method('csv', 'csv_parser');
  $self->parse_mode('html');

  # Default labels for corresponding targets
  $self->{labels}{quote}    = [@Default_Quote_Labels];
  $self->{labels}{dividend} = [@Default_Dividend_Labels];
  $self->{labels}{split}    = [@Default_Split_Labels];

  $self;
}

### User interface stubs

sub quotes    { shift->auspices('quote', @_)    }
sub dividends { shift->auspices('dividend', @_) }
sub splits    { shift->auspices('split', @_)    }

sub auspices {
  my $self   = shift;
  my $target = shift;
  $target or croak "Target type required\n";
  $self->{current_target} = $target;
  my $tmethod = $self->{targets}{$target}
    or croak "Unknown target ($target)\n";
  my $umethod = "${target}_urls";
  my $gmethod = "${target}_get";
  my $emethod = "${target}_extract";
  if ($self->can($umethod)) {
    return $self->$gmethod(@_);
  }
  elsif ($self->can($emethod)) {
    print STDERR "Fetching $tmethod under the auspice of quotes\n"
      if $self->{verbose};
    $self->auspice($tmethod);
    $self->quotes(@_);
    $self->auspice($tmethod);
    return $self->extraction($target);
  }
  else {
    print STDERR "Class ", ref $self, " cannot retrieve $tmethod.\n"
      if $self->{verbose};
    return ();
  }
}

sub target_worthy {
  my($self, $auspice) = @_;
  my $target;
  if (!$auspice) {
    $target  = $self->{current_target};
    $auspice = $self->{targets}{$target};
  }
  else {
    foreach (keys %{$self->{targets}}) {
      $target = $_ if $self->{targets}{$_} eq $auspice;
    }
  }
  croak "Unknown auspice ($auspice)\n" unless $target;
  my $umethod = "${target}_urls";
  my $emethod = "${target}_extract";
  return 1 if $self->can($umethod);
  return 1 if $self->can($emethod);
  0;
}

### Target methods

# In the Generic module, we provide the following TARGET based methods
# (which can of course be overridden):
#
#    quote_urls
#    quote_get
#    quote_labels
#    dividend_get
#    dividend_labels
#    split_labels
#    dividend_get
#    quote_source
#    dividend_source
#    split_source
#
# "quote_extract" is performed intrinsically at this point, so is not
# needed in an explicit sense, yet. This should probably change.
#
# The following methods are left entirely for subclass
# implementation. The existence of either TARGET_urls or
# TARGET_extract will be enough to retrieve the disired information,
# assuming it can be extracted with either direct queries or
# incidental extraction:
#
#    dividend_urls
#    split_urls
#    dividend_extract
#    split_extract
#
# Adding a new target will produce the need for a whole set of methods
# based on that target name. These are left up to the subclass as
# well.

sub quote_get    { shift->target_get('quote',    @_) }
sub split_get    { shift->target_get('split',    @_) }
sub dividend_get { shift->target_get('dividend', @_) }

sub quote_labels    { shift->target_labels('quote')    }
sub dividend_labels { shift->target_labels('dividend') }
sub split_labels    { shift->target_labels('split')    }

sub quote_source    { shift->target_source('quote',    @_) }
sub dividend_source { shift->target_source('dividend', @_) }
sub split_source    { shift->target_source('split',    @_) }

### Other stubs for subclass override for particular quote source

sub currency { undef }

sub method   { 'GET' }

### Data retrieval

sub ua { shift->{ua} }

sub auspice {
  my $self = shift;
  if (!$self->{auspice}) {
    $self->{auspice} = $self->{targets}{$self->{current_target}};
  }
  @_ ? $self->{auspice} = shift : $self->{auspice};
}

sub fetch {
  # HTTP::Request Wranger
  my $self = shift;
  my $mode = shift;
  $mode or croak "Request mode required\n";
  my $url  = shift;
  $url or croak "URL required\n";

  my $trys = $self->{attempts};
  my $response = $self->ua->request(HTTP::Request->new($mode, $url), @_);
  $self->{_lwp_success} = 0;
  while (! $response->is_success) {
    last unless $trys;
    print STDERR "Bad fetch",
       $response->is_error ? ' (' . $response->status_line . '), ' : ', ',
       "trying again...\n" if $self->{verbose};
    $response = $self->ua->request(new HTTP::Request($mode, $url), @_);
    --$trys;
  }
  $self->{_lwp_success} = $response->is_success;
  return undef unless $response->is_success;
  print STDERR "Fetch complete.\n" if $self->{verbose};
  $response->content;
}

# Aiigh, the beast!

sub target_get {
  # Initiates and consolidates row retrieval across the URLs provided
  # by the provided TARGET_urls subroutine. Other potential TARGET
  # methods include TARGET_labels, TARGET_extract, and TARGET_labels.
  #
  # This method is currently more complex than it really needs to be,
  # primarily because it treats 'quote' differently from other
  # targets.
  my($self, $target) = @_;
  my $tgoal = $self->{targets}{$target}
    or croak "Unknown target type ($target)\n";
  $self->{current_target} = $target;

  my $auspice  = $self->auspice || $self->{targets}{$target};

  # Cache (tgoal and auspice could be the same, but not always)
  if ($self->{extracts}{$tgoal} && $self->{extracts}{$auspice}) {
    return wantarray ?
      @{$self->{extracts}{$target}} : $self->{extracts}{$target};
  }

  my $urlmaker = "${target}_urls";
  my $fetcher  = "${target}_get";

  # For basic quote fetches, we can fall back to the traditional
  # "urls" method for backwards compatability.
  if ($target eq 'quote') {
    $urlmaker = 'urls' unless $self->can($urlmaker);
  }

  # The URL maker is essential
  $self->can($urlmaker)
    or croak ref $self . " does not have method $urlmaker\n";

  if (!$self->{quiet} && !$self->adjusted && !$self->has_non_adjusted) {
    print STDERR "WARNING: Non-adjusted values requested, but class ",
       ref $self, " only provides pre-adjusted data\n";
  }

  my $lmethod = $self->labels_method;
  my @column_labels = $self->$lmethod();
  my(@rows, %empty_fetch, %saw_good_rows);

  foreach my $s ($self->symbols) {
    foreach ($self->$urlmaker($s)) {
      if ($empty_fetch{$s}) {
	print STDERR ref $self,
	   " passing on $s ($target) for now, empty fetch\n"
	     if $self->{verbose};
	last;
      }
      print STDERR "Processing ($s:$target) $_\n" if $self->{verbose};

      # We're a bit more persistent with quotes. It is more suspicious
      # if we get no quote rows, but it is nevertheless possible.
      my $trys = $target eq 'quote' ? $self->{attempts} : 1;
      my $initial_trys = $trys;
      my($data, $rows);
      $self->{_lwp_success} = 1; # gotta go through at least once
      while ((!$rows || !@$rows) && $trys && $self->{_lwp_success}) {
	print STDERR "$s Trying ($target) again due to no rows...\n"
	  if $self->{verbose} && $trys != $initial_trys;
	$data = $self->fetch($self->method, $_);
	$rows = $self->rows($data, @column_labels);
	--$trys;
      }

      if ($target ne 'quote') {
	# We are not very stubborn about dividends, splits, and other
	# non quotes right now. This is because we cannot prove a
	# successful negative (i.e., say there were no dividends or
	# splits over the time period...or perhaps there were, but it
	# is a defunct symbol...whatever...quotes should always be
	# present unless they are defunct, which is dealt with later.
	if (!$self->{_lwp_success} || !defined $data) {
	  ++$empty_fetch{$s};
	}
	elsif ($self->{_lwp_success} && !@$rows) {
	  ++$empty_fetch{$s};
	}
      }

      # House clean
      undef $data;

      # Extraction filters. This is an opportunity to extract rows
      # that are not what we are looking for, but contain valuable
      # information nevertheless. An example of this would be the
      # split and dividend rows you see in Yahoo HTML quote output. An
      # extraction filter method should expect an array ref as an
      # argument, representing a single row, and should return another
      # array ref with extracted output. If there is a return value,
      # then this row will be filtered from the primary output.
      my(%extractions, $ecount, $rc);
      $rc = @$rows;
      if ($self->extractors) {
	my(@filtered, $row);
	while ($row = pop(@$rows)) {
	  my $erow;
	  foreach my $mode ($self->extractors) {
	    my $em = "${mode}_extract";
	    if ($erow = $self->$em($row)) {
	      print STDERR "$s extract ($mode) got $s, ",
	         join(', ', @$erow), "\n";
	      if ($mode ne $target) {
		push(@{$extractions{$mode}}, [@$erow]);
		++$ecount;
	      }
	      else {
		# When the extractor is the same as the current target
		# type, put the data up front.
		push(@filtered, $row);
	      }
	      last;
	    }
	  }
	  push(@filtered, $row) unless $erow;
	}
	if ($self->{reverse}) {
	  foreach (keys %extractions) {
	    @{$extractions{$_}} = reverse @{$extractions{$_}}
	  }
	}

	if ($self->{verbose} && $ecount) {
	  print STDERR "$s Trimmed to ",$rc - $ecount,
	     " rows after $ecount extractions.\n";
	}

	$rows = \@filtered;
	# Undo the affects of our popping
	@$rows = reverse @$rows;
      }

      # Normalization. Saving the rounding operations until after the
      # adjust routine is deliberate since we don't want to be
      # auto-adjusting pre-rounded numbers.
      $self->date_normalize($rows);
      $self->number_normalize($rows);

      # Do the same for the extraction rows
      foreach (keys %extractions) {
	my $ct = $self->{current_target};
	$self->{current_target} = $_;
	$self->date_normalize($extractions{$_});
	$self->number_normalize($extractions{$_});
	$self->{current_target} = $ct;

	# store in the background
	push(@{$self->{extracts}{$_}}, map([$s, @$_], @{$extractions{$_}}));
      }

      if ($target eq 'quote') {
	# Ideally, this would merely be another extraction filter for
	# target 'quote'...maybe later.
	my $count = @$rows;
	@$rows = grep(! $self->non_quote_row($_), @$rows);
	if ($self->{verbose}) {
	  if ($count == @$rows) {
	    print STDERR "$s Retained $count rows\n";
	  }
	  else {
	    print STDERR "$s Retained $count raw rows\n, trimmed to ",
	       scalar @$rows, " rows due to noise\n";
	  }
	}

	# Auto adjust if applicable
	$self->adjust($rows) if $self->adjuster;

	# zcount is an attempt to capture null values; if there are
	# too many we assume there is something wrong with the remote
	# data
	my $close_column = $self->target_label_map->{close};
	my($zcount, $hcount);
	$zcount = $hcount = 0; # -w
	foreach (@$rows) {
	  foreach (@$_) {
	    # Sometimes N/A appears
	    s%^\s*N/A\s*$%%;
	  }
	  my $q = $_->[$close_column];
	  if ($q =~ /\d+/) { ++$hcount }
	  else             { ++$zcount }
	}
	my $pct = $hcount ? 100 * $zcount / ($zcount + $hcount) : 100;
	if (!$trys || $pct >= $self->{zthresh}) {
	  ++$empty_fetch{$s} unless $saw_good_rows{$s};
	}
	else {
	  # For defunct symbols, we could conceivably get quotes over
	  # a date range that contains blocks of time where the ticker
	  # was actively traded, as well as blocks of time where the
	  # ticker doesn't exist. If we got good data over some of the
	  # blocks, then we take note of it so we don't toss the whole
	  # set of queries for this symbol.
	  ++$saw_good_rows{$s};
	}

	$self->precision_normalize($rows) if $self->{quote_precision};
      }

      push(@rows, map([$s, @$_], @$rows));
    }
  }

  # Set source for successful extractions, before the extracts area
  # gets potentilaly populated by champion extractions.
  foreach my $mode ($self->extractors) {
    next if !@rows || $mode eq $target;
    my $erows;
    next unless $erows = $self->{extracts}{$mode};
    foreach my $erow (@$erows) {
      $self->target_source($mode, $erow->[0], ref $self);
    }
  }

  # Check for bad fetches.  If we failed on some symbols, punt them to
  # our champion class.
  if (%empty_fetch) {
    my @bad_symbols = sort keys %empty_fetch;
    print STDERR "Bad fetch for ", join(',', @bad_symbols), "\n"
      if $self->{verbose};
    my $champion;
    my $mystic = $self;
    while($champion = $mystic->_summon_champion(@bad_symbols)) {
      print STDERR "Seeing if ", ref $champion, " can get $auspice\n"
	if $self->{verbose};
      last if $champion->target_worthy($auspice);
      $mystic = $champion;
      $champion = undef;
    }
    if ($champion) {
      print STDERR ref $champion, ", my hero!\n" if $self->{verbose};
      # Hail Mary
      push(@rows, $champion->$auspice(@_));
      # Our champion, or one of their champions, was the source for
      # these symbols (including extracted info).
      foreach my $mode ($champion->sourced_modes) {
	foreach ($champion->sourced_symbols($mode)) {
	  $self->target_source($mode, $_,
			       $champion->target_source($mode, $_));
	}
	if ($mode ne $target) {
	  push(@{$self->{extracts}{$mode}}, $champion->extraction($mode));
	}
      }
    }
    elsif (! $self->{quiet}) {
      print STDERR "WARNING: Could not fetch $auspice for some symbols (",join(', ', @bad_symbols), "). Abandoning request for these symbols.";
      if ($auspice ne 'quotes') {
	print STDERR " Don't worry, though, we were looking for $auspice. These are less likely to exist compared to quotes.\n";
      }
      else {
	print STDERR "\n";
      }
    }
  }

  # Set ourselves as the source for successful symbols from the direct
  # query.
  foreach ($self->symbols) {
    next if $empty_fetch{$_};
    $self->target_source($target, $_, ref $self);
  }

  if ($self->{verbose}) {
    print STDERR "Class ", ref $self, " returning ", scalar @rows,
       " composite rows.\n";
  }
  
  # Cache
  $self->{extracts}{$target} = \@rows;

  # Return the loot.
  wantarray ? @rows : \@rows;
}

sub rows {
  my($self, $data_string, @column_labels) = @_;
  return [] unless $data_string;
  if (!@column_labels) {
    my $lmethod = $self->labels_method;
    @column_labels = $self->$lmethod();
  }

  my $method = $self->parse_method
    or croak "No parse method found for " . $self->parse_mode . "\n";
  my $rows = $self->$method($data_string, @column_labels);

  @$rows = reverse @$rows if $self->{reverse};

  my $rc = @$rows;
  print STDERR "Got $rc raw rows\n" if $self->{verbose};

  # Prep the rows
  foreach (@$rows) {
    foreach (@$_) {
      # Zap leading and trailing white space
      s/^\s+//;
      s/\s+$//;
    }
  }
  # Pass only rows with a valid date that is in range (and store the
  # processed value while we are at it)
  my @date_rows;
  my $dcol = $self->target_label_map->{date};
  my $r;
  while($r= pop @$rows) {
    my $date = $self->date_in_range($r->[$dcol]);
    next unless $date;
    $r->[$dcol] = $date;
    push(@date_rows, $r);
  }
  @date_rows = reverse @date_rows;

  print STDERR "Trimmmed to ", scalar @date_rows, " applicable date rows\n"
    if $self->{verbose} && @date_rows != $rc;

  \@date_rows;
}

### Adjustment triggers and manipulation

sub adjuster {
  # In order to be an adjuster, it must first be enabled. In addition,
  # there has to be a column specified as the adjusted value. This is
  # not as generic as I would like it, but so far it's just for
  # Yahoo...it should work for any site with "adj" in the column
  # label...this column should be the adjusted closing value.
  my $self = shift;
  return 0 if !$self->{adjusted};
  foreach ($self->quote_labels) {
    return 1 if /adj/i;
  }
  0;
}

sub adjusted {
  # Request adjusted or non-adjusted data (circumstances allowing)
  my($self, $adjusted) = @_;
  if (defined $adjusted) {
    $self->{adjusted} = $adjusted;
    $self->clear_cache();
  }
  $self->{adjusted};
}

sub has_non_adjusted {
  # This is just a flag so that warnings can be issued when
  # non-adjusted data has been requested, but a data source only
  # provides adjusted values. Most sites provide pre-adjusted values,
  # so this is 0 by default...if a site can provide non-adjusted
  # values (such as Yahoo), then the site-specific module must say so.
  shift->{has_non_adjusted};
}

sub adjust {
  # Assuming we are enabled and have the adjusted value present,
  # figure out the ratio based on the closing price, and adjust the
  # corresponding values accordingly.
  my($self, $rows) = @_;
  my $adj_col;

  # Do nothing if there is no adjusted value present.
  return undef unless $self->adjuster;

  my $labelmap = $self->target_label_map;

  foreach my $row (@$rows) {
    # Only bother if needed
    next if $row->[$labelmap->{close}] == $row->[$labelmap->{adj}];
    if (!$row->[$labelmap->{adj}]) {
      print STDERR "Oops...zero value for adjusted, skipping row.\n"
	if $self->{verbose};
      next;
    }

    my $rat = $row->[$labelmap->{close}]/$row->[$labelmap->{adj}];
    $rat = sprintf("%.$self->{ratio_precision}f", $rat)
      if $self->{ratio_precision};
    # these are divided by the ratio
    foreach (qw(open high low close)) {
      $row->[$labelmap->{$_}] = $row->[$labelmap->{$_}]/$rat;
    }
    # volume is multiplied by the ratio
    $row->[$labelmap->{volume}] = $row->[$labelmap->{volume}] *= $rat;
  }
  $rows;
}

### Bulk manipulation filters

sub date_normalize {
  # Place dates into a consistent format, courtesy of Date::Manip
  my($self, $rows) = @_;
  my $dcol = $self->target_label_map->{date};
  foreach my $row (@$rows) {
    my $d = ParseDate($row->[$dcol]);
    next unless $d;
    $row->[$dcol] = join('/', $self->ymd($d));
  }
  $rows;
}

sub number_normalize {
  # Strip non-numeric noise from numeric fields
  my($self, $rows) = @_;
  my $labelmap = $self->target_label_map;
  foreach my $row (@$rows) {
    foreach (grep(!/date/i, keys %$labelmap)) {
      next unless defined $labelmap->{$_};
      $row->[$labelmap->{$_}] =~ s/[^\d\.]//go;
    }
  }
  $rows;
}

sub precision_normalize {
  # Round off numeric fields, if requested (%.4f by default). Volume
  # is the exception -- we just round that into an integer. This
  # should probably only be called for 'quote' targets because it
  # knows details about where the numbers of interest reside.
  my($self, $rows) = @_;
  croak "precision_normalize invoked in '$self->{current_target}' mode rather than 'quote' mode.\n" unless $self->{current_target} eq 'quote';
  my $labelmap = $self->target_label_map;
  foreach my $row (@$rows) {
    foreach (qw(open high low close adj)) {
      next unless defined $labelmap->{$_};
      $row->[$labelmap->{$_}] = sprintf("%.$self->{quote_precision}f",
					$row->[$labelmap->{$_}]);
    }
    $row->[$labelmap->{volume}] = sprintf("%d", $row->[$labelmap->{volume}]);
  }
  $rows;
}

### Single row filters

sub non_quote_row {
  my($self, $row) = @_;
  ref $row or croak "Row ref required\n";
  # Skip date in first field
  my $dcol = $self->target_label_map('quote')->{date};
  my @non_quotes;
  foreach (0 .. $#$row) {
    next if $_ == $dcol;
    next if $row->[$_] =~ /^\s*$/;
    if ($row->[$_] !~ /^\s*\$*[\d\.,]+\s*$/) {
      return $row;
    }
  }
  0;
}

sub date_in_range {
  my $self = shift;
  my $date = shift;
  $date = ParseDate($date) or return undef;
  $date =~ s/\d\d:.*//;
  $date ge $self->{start_date} && $date le $self->{end_date} ?
    $date : 0;
}

### Label to column-index mappers

sub target_labels {
  # We don't want to rely on this method internally, because sub
  # classes need to have an opportunity to override the
  # target-specific versions. Therefore, use labels_method() to
  # generate the method string, and invoke indirectly.
  my($self, $target, @labels) = @_;
  croak "Target name required\n" unless $target;
  if (@labels) {
    $self->{labels}{$target} = \@labels;
  }
  @{$self->{labels}{$target}};
}

sub labels_method {
  my($self, $target) = @_;
  $target = $self->{current_target} unless $target;
  $target = 'quote' unless $target;
  $target . '_labels';
}

sub label_map {
  # This provides two things: requested column ordering and normalized
  # column labels for use in programming.  We try to normalize on the
  # variations of possible labels for close, high, volume, etc, so
  # that we can still do meaningful things with them even if the
  # labels might vary slightly.
  #
  # For example, the column labels "Cash Dividends" or "Dividend"
  # would both get the map label of 'div' -- obviously both should not
  # be present on the same site, this is meant to normalize map labels
  # across site instances with slightly different characteristics
  # (although this has not proven necessary as of yet...better robust
  # than sorry, though).
  #
  # As an added bonus, column labels can be provided as arguments for
  # a custom label map -- this comes in handy for different parse
  # modes such as CSV where the column reordering does not happen
  # automatically like it does in HTML::TableExtract. The custom label
  # map ordering has to be reconciled with the requested column
  # ordering in the default label map.

  my($self, @labels) = @_;
  @labels or croak "Label list required\n";
  @labels = map(lc $_, @labels);
  my $lpat = join('|', @labels);

  # Current target labels (these are our referrent for normalizing
  # keys of the labelmap)
  my $lmethod = $self->labels_method;
  my @clabels  = map(lc $_, $self->$lmethod());
  my $clpat    = join('|', @clabels);

  if (!$self->{labelcache}{$lpat}) {
    # Normalize. If it's an oddball just use the unaltered label as
    # the key. Also, if the various column labels every become more
    # complicated (they can actually be regexps) then we will have to
    # provide translations from the regexps to 'adj', 'close', etc.
    my %labelmap;
    foreach (0 .. $#labels) {
      if ($labels[$_] =~ /($clpat)/i) {
	$labelmap{lc($1)} = $_;
      }
      else {
	$labelmap{$labels[$_]} = $_;
      }
    }
    $self->{labelcache}{$lpat} = \%labelmap;
  }
  $self->{labelcache}{$lpat};
}

sub target_label_map {
  # Produce the label map for the current target
  my $self   = shift;
  my $target = shift;
  $target = $self->{current_target} unless $target;
  $target = 'quote' unless $target;
  my $lmethod = "${target}_labels";
  croak "Class " . ref $self . " has no $lmethod. Cannot generate labels.\n"
    unless $self->can($lmethod);
  $self->label_map($self->$lmethod());
}

### Parser register, state

sub parse_method {
  my($self, $mode, $parse_sub) = @_;
  $mode = $self->{parse_mode} unless $mode;
  if ($parse_sub) {
    $self->{parse_methods}{$mode} = $parse_sub;
  }
  $self->{parse_methods}{$mode};
}

sub parse_mode {
  my($self, $mode) = @_;
  if ($mode) {
    if (!$self->{parse_methods}{$mode}) {
      croak "Unregistered parse mode ($mode)\n";
    }
    $self->{parse_mode} = $mode;
  }
  $self->{parse_mode};
}

### Parser methods

sub html_table_parser {
  my($self, $html_string, @column_labels) = @_;
  if (!@column_labels) {
    my $lmethod = $self->labels_method;
    print STDERR "Lables generated by $lmethod: ";
    @column_labels = $self->$lmethod();
    print STDERR join('|', @column_labels),"\n";
  }
  my $te = HTML::TableExtract->new(
				   headers => \@column_labels,
				   automap => 1,
				   debug   => $self->{debug},
				  );
  $te->parse($html_string);
  [$te->rows];
}

sub csv_parser {
  # CSV_XS or something similar should probably be used here to be
  # properly generic; however, Yahoo is the only CSV source so far,
  # and is fairly consistent (with quotes, anyway, dividends suck). I
  # would like to avoid introducing the C dependencies in CSV_XS for
  # now.
  my($self, $csv_data, @column_labels) = @_;

  if (!@column_labels) {
    my $lmethod = $self->labels_method;
    @column_labels = $self->$lmethod();
  }

  my(@csv_lines) = split("\n", $csv_data);
  return [] if !@csv_lines || $csv_lines[0] =~ /(no data)|error/i;
  undef $csv_data;
  chomp(@csv_lines);
  my(@cnames, $label_map);

  # Use the first line of the CSV data to establish the *existing*
  # column order in the data. We rearrange the CSV columns based on
  # the desired column labels, the order of which might be different.
  my $cpat = join('|', @column_labels);
  if ($csv_lines[0] =~ /$cpat/i) {
    $label_map = $self->label_map($self->_parse_csv_line($csv_lines[0]));
    shift @csv_lines;
  }
  else {
    print STDERR "WARNING: No column labels in the CSV data, assuming current ($self->{current_target}) labels\n" unless $self->{quiet};
    $label_map = $self->label_map(@csv_lines);
  }

  # Find the order of keys in the default label map. Note that by
  # taking a slice of the label map, unrequested columns are
  # eliminated.
  my $dlm = $self->label_map(@column_labels);
  my @ordered_lkeys = sort { $dlm->{$a} <=> $dlm->{$b} } keys %$dlm;
  my @reordered_label_indicies = @{$label_map}{@ordered_lkeys};

  # We have to generate the pattern for each batch because Yahoo uses
  # a space for dividend CSV data and a comma for quote CSV
  # data. Urk.
  my $csv_pat = $self->_csv_pat;
  my @rows;
  foreach (@csv_lines) {
    push(@rows,
	 [($self->_parse_csv_line($_, $csv_pat))[@reordered_label_indicies]]);
  }
  \@rows;
}

sub _parse_csv_line {
  my($self, $line, $pat) = @_;
  $pat = $self->_csv_pat unless $pat;
  my @fields  = ();
  push(@fields, $+) while $line =~ /$pat/g;
  push(@fields, undef) if substr($line, -1,1) eq $self->csv_sep_char;
  @fields;
}

sub _csv_pat {
  my $self = shift;
  my $qc = $self->csv_sep_char;
  # CSV line parser yanked from Perl Cookbook, ala Finance::Quote...
  qr/
     # the first part groups the phrase inside the quotes.
     # see explanation of this pattern in MRE
     "([^\"\\]*(?:\\.[^\"\\]*)*)"$qc?
       | ([^$qc]+)$qc?
       | $qc
  /x;
}

sub csv_sep_char {
  my $self = shift;
  if (@_) {
    $self->{_csv_sep} = shift;
  }
  defined $self->{_csv_sep} ? $self->{_csv_sep} : ',';
}

### Extractors, extraction results

sub extractors {
  my $self = shift;
  my(%seen, @extractors);
  foreach (@{$self->{target_order}}) {
    next if $seen{$_};
    ++$seen{$_};
    next unless $self->can("${_}_extract");
    push(@extractors, $_);
  }
  @extractors;
}

sub extraction {
  my($self, $target) = @_;
  $target or croak "Target type required\n";
  croak "Unknown target type ($target)\n" unless $self->{targets}{$target};
  my $ext = $self->{extracts}{$target};
  $ext = [] unless ref $ext;
  wantarray ? @$ext : $ext;
}

### Accessors, generators

sub start_date {
  my($self, $start_date) = @_;
  if ($start_date) {
    $self->clear_cache;
    $self->{start_date} = $start_date;
  }
  $self->{start_date};
}

sub end_date {
  my($self, $end_date) = @_;
  if ($end_date) {
    $self->clear_cache;
    $self->{end_date} = $end_date;
  }
  $self->{end_date};
}

sub mydates {
  my $self = shift;
  $self->dates($self->{start_date}, $self->{end_date});
}

sub dates {
  my($self, $sdate, $edate) = @_;
  $sdate && $edate or croak "Start date and end date strings required\n";
  my $sd = ParseDate($sdate) or croak "Could not parse start date $sdate\n";
  my $ed = ParseDate($edate) or croak "Could not parse end date $edate\n";
  ($sd, $ed) = sort($sd, $ed);
  $sd =~ s/\d\d:.*//;
  $ed =~ s/\d\d:.*//;
  my @dates;
  push(@dates, $sd) if Date_IsWorkDay($sd);
  my $cd = Date_NextWorkDay($sd, 1);
  $cd =~ s/\d\d:.*//;
  while ($cd <= $ed) {
    push(@dates, $cd);
    $cd = Date_NextWorkDay($cd);
    $cd =~ s/\d\d:.*//;
  }
  @dates;
}

sub symbols {
  my($self, @symbols) = @_;
  if (@symbols) {
    my %seen;
    grep(++$seen{$_}, grep(uc $_, @symbols));
    $self->{symbols} = [sort keys %seen];
    $self->clear_cache;
  }
  @{$self->{symbols}};
}

sub successors {
  my $self = shift;
  @{$self->{successors}};
}

sub clear_cache {
  my $self = shift;
  $self->{extracts} = {};
  $self->{labelcache}  = {};
  1;
}

### Post fetch analysis

sub sourced_modes {
  my $self = shift;
  return () unless $self->{sources};
  sort keys %{$self->{sources}};
}

sub sourced_symbols {
  # What symbols do we know the source of?
  my($self, $target) = @_;
  $target = $self->{current_target} unless $target;
  $target = 'quote' unless $target;
  return () unless $self->{sources}{$target};
  sort keys %{$self->{sources}{$target}};
}

sub source {
  my($self, $symbol, $source) = @_;
  croak "Ticker symbol required\n" unless $symbol;
  my $target = $self->{current_target};
  $target = 'quote' unless $target;
  if ($source) {
    $self->target_source($target, $symbol, $source);
  }
  $self->{sources}{$target}{$symbol};
}

sub target_source {
  my($self, $target, $symbol, $source) = @_;
  croak "Target mode required\n"   unless $target;
  croak "Ticker symbol required\n" unless $symbol;
  $symbol = uc $symbol;
  if ($source) {
    $self->{sources}{$target}{$symbol} = $source;
  }
  $self->{sources}{$target}{$symbol};
}

###

sub _summon_champion {
  # Instantiate the next class in line if this class failed in
  # fetching any quotes. Make sure and pass along the remaining
  # champions to the new champion.
  my($self, @bad_symbols) = @_;
  return undef unless ref $self->{lineup} && @{$self->{lineup}};
  my @lineup = @{$self->{lineup}};
  my $champ_class = shift @lineup;
  print STDERR "Loading $champ_class\n" if $self->{verbose};
  eval "require $champ_class;";
  die $@ if $@;
  my $champion = $champ_class->new
    (
     symbols    => [@bad_symbols],
     start_date => $self->{start_date},
     end_date   => $self->{end_date},
     adjusted   => $self->{adjusted},
     verbose    => $self->{verbose},
     lineup     => \@lineup,
    );
  $champion;
}

### Toolbox

sub ymd {
  my $self = shift;
  shift =~ /^\s*(\d{4})(\d{2})(\d{2})/o;
}

#### Deprecated

sub getquotes     { shift->quote_get(@_)    }
sub column_labels { shift->quote_labels(@_) }

1;
__END__

=head1 NAME

Finance::QuoteHist::Generic - Base class for retrieving historical stock quotes.

=head1 SYNOPSIS

  package Finance::QuoteHist::MyFavoriteSite;
  use strict;
  use vars qw(@ISA);
  use Finance::QuoteHist::Generic;
  @ISA = qw(Finance::QuoteHist::Generic);

  sub quote_urls {
    # This method should return the set of URLs necessary to extract
    # the quotes from this particular site given the list of symbols
    # and date range provided during instantiation. See
    # Finance::QuoteHist::MotleyFool for a basic example of how to do
    # this, or Finance::QuoteHist::Yahoo for a more complicated
    # example.
  }

=head1 DESCRIPTION

This is the base class for retrieving historical stock quotes. It is
built around LWP::UserAgent, and by default it expects the returned
data to be in HTML format, in which case the quotes are gathered using
HTML::TableExtract. Support for CSV (Comma Separated Value) data is
included as well.

In order to actually retrieve historical stock quotes, this class
should be subclassed and tailored to a particular web site.  In
particular, the C<quote_urls()> method should be overridden, and
provide however many URLs are necessary to retrieve the data over a
list of symbols within the given date range.  Different sites have
different limitations on how many quotes are returned for each
query. See Finance::QuoteHist::MotleyFool,
Finance::QuoteHist::FinancialWeb, and Finance::QuoteHist::Yahoo for
some examples of how to do this.

For more complicated sites, such as Yahoo, more methods are available
for overriding that deal with things such as splits and dividends.

=head1 METHODS

=over

=item new()

Returns a new Finance::QuoteHist::Generic object.  Valid attributes
are:

=over

=item start_date

=item end_date

Specify the date range from which you would like historical quotes.
These dates get parsed by the C<ParseDate()> method in Date::Manip, so
see L<Date::Manip(3)> for more information on valid date strings.
They are quite flexible, and include such strings as '1 year
ago'. Date boundaries can also be dynamically set with methods of the
same name.

=item symbols

Indicates which ticker symbols to include in the search for historical
quotes. Passed either as a string (for single ticker) or an array ref
for multiple tickers.

=item reverse

Indicates whether each batch of rows from each URL provided in
C<quote_urls()> should be reversed from top to bottom.  Some sites
present historical quotes with the newest quotes on the top.  Since
the rows from each URL are eventually catenated, if the overall order
of your rows is important you might want to pay attention to this
flag. If the overall order is not that important, then ignore this
flag. Typically, site-specific sub classes of this module will take
care of setting this appropriately. The default is 0.

=item attempts

Sets how persistently the module tries to retrieve the quotes. There
are two places this will manifest. First, if there are what appear to
be network errors, this many network connections are attempted for
that URL. Secondly, for quotes only, if a document was successfully
retrieved, but it contained no quotes, this number of attempts are
made to retrieve a document with data. Sometimes sites will report a
temporary internal error via HTML, and if it is truly transitory this
will usually get around it. The default is 3.

=item lineup

Passed as an array reference (or scalar for single site), this list
indicates which Finance::QuoteHist::Generic sub classes should be
invoked in the event this class fails in its attempt to retrieve
historical quotes. In the event of failure, the first class in this
list is invoked with the same parameters as the original class, and
the remaining classes are passed as the lineup to the new class. This
sets up a daisy chain of redundancy in the event a particular site is
hosed. See L<Finance::QuoteHist(3)> to see an example of how this is
done in a top level invocation of these modules. This list is empty by
default.

=item quote_precision

Sets the number of decimal places to which quote values are
rounded. This might be of particular significance if there is
auto-adjustment taking place (which is only under particular
circumstances currently...see L<Finance::QuoteHist::Yahoo>). Setting
this to 0 will disable the rounding behavior, returning the quote
values as they appear on the sites (assuming no auto-adjustment has
taken place). The default is 4.

=item verbose

When set, many status messages are printed to STDERR indicating
progression through URLs and lineup invocations.

=item quiet

When set, certain failure messages are suppressed from appearing on
STDERR. These messages would normally appear regardless the setting of
the C<verbose> flag.

=back

=back

The following methods are the primary user interface methods; methods
of interest to developers wishing to make their own site-specific
instance of this module will find information on overriding methods
further below.

=over

=item quotes()

Retrieves historical quotes for all provided symbols over the
specified date range. Depending on context, returns either a list of
rows or an array reference to the same list of rows.

=item dividends()

=item splits()

If available, retrieves dividend or split information for all provided
symbols over the specified date range. If there are no site-specific
subclassed modules in the B<lineup> capable of getting dividends or
splits, the user will be notified on STDERR unless the B<quiet> flag
was requested during object creation.

=item start_date(date_string)

=item end_date(date_string)

Set the date boundaries of all queries. The B<date_string> is
interpreted by the Date::Manip module.

=item clear_cache()

When results are gathered for a particular date range, whether they be
via direct query or incidental extraction, they are cached. This cache
is cleared by invoking this method directly, by resetting the boundary
dates of the query, or by changing the C<adjusted()> setting.

=item quote_source(ticker_symbol)

=item dividend_source(ticker_symbol)

=item split_source(ticker_symbol)

After query, these methods can be used to find out which particular
subclass in the B<lineup> fulfilled the corresponding request.

=back

The following methods are the primary methods of interest for
developers wishing to make a site-specific subclass. For simple quote
retrievals, the C<quote_urls()> method is typically all that is
necessary. For splits, dividends, and more complicated data parsing
conditions beyond HTML tables, the other methods could be of interest
(see the Finance::QuoteHist::Yahoo module as an example of the more
complicated behavior). If a new target type is ever defined in
addition to B<quote>, B<split>, and B<dividend>, then corresponding
methods (C<TARGET_urls()>, C<TARGET_get()>, C<TARGET_symbols()>)
should be provided when appropriate.

=over

=item quote_urls()

When a site supports historical stock quote queries, this method
should return the list of URLs necessary to retrieve all historical
quotes from a particular site for the symbols and date ranges
provided.

=item dividend_urls()

If a site supports direct dividend queries, this method should provide
the list of URLs necessary for the symbol and date range
involved. Currently this is only implemented by the Yahoo subclass.

=item split_urls()

If a site supports direct split queries, this method should provide
the list of URLs necessary. Currently no sites support this type of
query (splits are gathered from the regular quote output from Yahoo).

=item quote_get()

=item dividend_get()

=item split_get()

All three of these methods invoke C<target_get()> with the relevant
target information. The analogous methods, C<quotes()>,
C<dividends()>, and C<splits()>, should automatically take care of
finding these based on the presence of the corresponding
C<TARGET_urls()> method. If the C<TARGET_urls()> method is not
available, then they will look for ways to utilize the
C<TARGET_extract()> method.

=item split_extract()

=item dividend_extract()

These extraction methods are not provided by default. When present in
a site-specific subclass, they are invoked on a per-row basis during
direct (i.e., via URLs provided by a C<TARGET_urls()> method) queries
of other target types; it is passed an array reference representing a
table row, and should return another array reference representing
successfully extracted dividend/split information. When a successful
extraction occurs, that row is filtered from the target query
results. See the Yahoo subclass for an example of its
use. Theoretically there could be a C<quote_extract()> method as well,
but it is redundant at this point and therefore never used.

=item adjusted($boolean)

Return or set whether results should be returned as adjusted or
non-adjusted values. B<Adjusted> means that the quotes have been
retroactively adjusted in terms of the current share price, such as
for splits. The sites represented so far by site-specific subclassing
all offer pre-adjusted data by default, and most offer nothing
else. One significant exception is Yahoo, which provides non-adjusted
quotes in HTML, but adjusted for CSV, the default mode of transmission
for the Yahoo module. Pre-adjusted quote values can be requested from
capable sites by providing a true value to this method. By default,
adjusted values are always returned.

If non-adjusted values have been requested, and a site in the
B<lineup> that does not provide non-adjusted values ends up fulfilling
the request, a warning is issued to STDERR (unless B<quiet> was
specified as a parameter to C<new()>). Currently, Yahoo is the only
supported site that provides non-adjusted values, but they have to be
specifically requested.

There are a couple of points to note that could be significant;
QuoteHist will automatically notice if a quote source has an "Adj"
column -- one that represents an adjusted closing value. If present,
all other values, including volume, will be adjusted based on the
ratio of the represented closing value and the adjusted value. This
might actually occur with the Yahoo module if, for example, you
request C<splits()> before you request C<quotes()>. The split data is
only available in HTML mode; QuoteHist caches initial queries and will
gather the quote information represented in the HTML. It will notice
the adjusted close column, and automatically normalize the rest of the
quote information. If non-adjusted data is desired, you must pass 0 to
this method. The justification for this is that there will be a common
expectation for quote data returned from different sites in the
B<lineup>, even if there are small deviations due to things such as
Yahoo adjusting for B<dividends> as well as splits, so there could be
slight variations across sites.

=item ua()

Accessor method for the LWP::UserAgent object used to process
HTTP::Request for individual URLs.

=back

Most of the methods below are utilized during a call to
C<target_get()>. Average subclasses will probably have little need of
them, but they are included here just in case.

=over

=item target_get($target)

Returns an array reference to the rows that result from a particular
TARGET query; this is where the network transaction and data
extraction take place. It will gather the results from each URL
provided in the corresponding TARGET_urls() method, perform the
primary and secondary data extraction, and return the catenated
results as a list. For example, the C<quote_get()> method will call
this method with 'quote' as the TARGET; during its execution, the
methods C<quote_urls()> and C<quote_labels()> will be invoked to
tailor the quote-specific retrieval and extraction.

=item fetch($mode, $url, @new_request_args)

Returns the web page located at C<$url>, using request method C<$mode>
(i.e., GET or POST). The C<@new_request_args> list gets passed as
arguments to the HTTP::Request::new method that handles the request at
the behest of the LWP::UserAgent accessible via the C<ua()> method.

=item method

Returns the method under which HTTP::Request objects are created for
use by the LWP::UserAgent. By default, this returns 'GET'.

=item has_non_adjusted($boolean)

Indicator method that specifies whether a particular site subclass is
capable of providing non-adjusted quote values. This is assumed to be
false by default; Yahoo is a significant exception.

=item rows($data_string)

Given an data string, returns the extracted rows as either an array or
array reference, depending on context. The data string is parsed based
on the type of parser registered for the data type; currently this is
either HTML via HTML::TableExtract, or CSV using an internal
parser. If parsing HTML, the corresponding target labels are passed
along to the HTML::TableExtract class. Rows falling outside of the
date range specified for the object are discarded.

=item parse_method($mode, $parse_sub)

Retrieve or set the reference or name of the parsing routine for the
specified TARGET. Currently parse methods are registered by default
for the 'html' and 'csv' modes.

=item parse_mode($mode)

Retrieve or set the current parse mode.

=item html_table_parser($data_string, @column_labels)

HTML table parser routine registered by default. C<column_labels> are
optional, and will default to the labels provided by the
C<TARGET_labels()> method, where TARGET is the current target mode.

=item csv_parser($data_string, @column_labels)

CSV parser routine registered by default. C<column_labels> are
optional, but when present represent the labels that might appear in
the beginning of the CSV data. They are reordered based on the
default C<column_labels> specified for HTML output.

=item date_in_range($date)

Given a date string, test whether it is within the range specified by
the current I<start_date> and I<end_date>.

=item dates($start_date, $end_date)

Returns a list of business days between and including the provided
boundary dates. If no arguments are provided, B<start_date> and
B<end_date> default to the currently specified date range.

=back

=head1 DISCLAIMER

The data returned from these modules is in no way guaranteed, nor are
the developers responsible in any way for how this data (or lack
thereof) is used. The interface is based on URLs and page layouts that
might change at any time. Even though these modules are designed to be
adaptive under these circumstances, they will at some point probably
be unable to retrieve data unless fixed or provided with new
parameters. Furthermore, the data from these web sites is usually not
even guaranteed by the web sites themselves, and oftentimes is
acquired elsewhere. See the documentation for each site-specific
module for more information regarding the disclaimer for that site.

Above all, play nice.

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000 Matthew P. Sisk.  All rights reserved. All wrongs
revenged. This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

Finance::QuoteHist(3), HTML::TableExtract(3), Date::Manip(3),
perlmodlib(1), perl(1).

=cut
