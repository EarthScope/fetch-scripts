#!/usr/bin/perl
#
# FetchDMCData
#
# Fetch bulk data from the DMC web interfaces.  This program is
# primarily written to select and fetch waveform data but can also
# fetch metadata and response information.
#
# Data selection
#
# Data is generally selected by specifying network, station, location,
# channel, quality, start time and end time.  The name parameters may
# contain wildcard characters.  All input options are optional but
# waveform requests should include a time window.  Data may be
# selected one of three ways:
#
# 1) Command line arguments: -N, -S, -L, -C, -Q, -s, -e
#
# 2) A selection file containing a list of:
#    Net Sta Loc Chan Qual Start End
#
# 3) A BREQ_FAST formatted file
#
# Data output
#
# miniSEED: If the -o option is used to specify an output file
# waveform data will be requested based on the selection and all
# written to the single file.
#
# metadata: If the -m option is used to specifiy a metadata file a
# line will be written to the file for each channel epoch and will
# contain:
# "net,sta,loc,chan,scale,lat,lon,elev,depth,azimuth,dip,instrument,start,end"
#
# This metadata file can be used directly with mseed2sac or tracedsp
# to create SAC files including basic metadata.
#
# SAC P&Zs: If the -sd option is given SAC Poles and Zeros will be
# fetched and a file for each channel will be written to the specified
# directory with the name 'SACPZ.Net.Sta.Loc.Chan'.  If this option is
# used while fetching waveform data, only channels which returned
# waveforms will be requested.
#
# RESP: If the -rd option is given SEED RESP (as used by evalresp)
# will be fetched and a file for each channel will be written to the
# specified directory with the name 'RESP.Net.Sta.Loc.Chan'.  If this
# option is used while fetching waveform data, only channels which
# returned waveforms will be requested.
#
#
# ## Change history ##
#
# 2010.140:
#  - Initial version
#
# 2010.148:
#  - Add options to fetch SAC P&Z and RESP data
#  - Make waveform collection optional
#  - Limit metadata channel epochs to be within request window
#  - Print "DONE" when finished
#
# Author: Chad Trabant, IRIS Data Managment Center

use strict;
use File::Basename;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Status qw(status_message);
use HTTP::Date;
use Data::Dumper;

my $version  = "2010.154";

# Web service for metadata
my $metadataservice = 'http://www.iris.edu/mds/';

# Web service for waveform data
my $waveformservice = 'http://www.iris.edu/ws/dataselect/query';

# Web service for SAC P&Z
my $sacpzservice = 'http://www.iris.edu/ws/sacpz/query';

# Web service for RESP
my $respservice = 'http://www.iris.edu/ws/resp/query';

# HTTP UserAgent reported to web services
my $useragent = "FetchDMCData/$version";

my $usage      = undef;
my $verbose    = undef;

my $net        = undef;
my $sta        = undef;
my $loc        = undef;
my $chan       = undef;
my $qual       = undef;
my $starttime  = undef;
my $endtime    = undef;
my $selectfile = undef;
my $bfastfile  = undef;
my $auth       = undef;
my $outfile    = undef;
my $sacpzdir   = undef;
my $respdir    = undef;
my $metafile   = undef;

# Parse command line arguments
Getopt::Long::Configure ("bundling_override");
my $getoptsret = GetOptions ( 'help|usage|h'   => \$usage,
                              'verbose|v+'     => \$verbose,
                              'net|N=s'        => \$net,
                              'sta|S=s'        => \$sta,
                              'loc|L=s'        => \$loc,
                              'chan|C=s'       => \$chan,
                              'qual|Q=s'       => \$qual,
			      'starttime|s=s'  => \$starttime,
			      'endtime|e=s'    => \$endtime,
			      'selectfile|l=s' => \$selectfile,
			      'bfastfile|b=s'  => \$bfastfile,
			      'auth|a=s'       => \$auth,
			      'outfile|o=s'    => \$outfile,
			      'sacpzdir|sd=s'  => \$sacpzdir,
			      'respdir|rd=s'   => \$respdir,
			      'metafile|m=s'   => \$metafile,
			    );

my $required =  ( defined $net || defined $sta ||
		  defined $loc || defined $chan ||
		  defined $starttime || defined $endtime ||
		  defined $selectfile || defined $bfastfile );

if ( ! $getoptsret || $usage || ! $required ) {
  my $script = basename($0);
  print "$script: collect waveform data from the IRIS DMC (version $version)\n\n";
  print "Usage: $script [options]\n\n";
  print " Options:\n";
  print " -v                Increase verbosity, may be specified multiple times\n";
  print " -N,--net          Network code, default is all\n";
  print " -S,--sta          Station code, default is all\n";
  print " -L,--loc          Location ID, default is all\n";
  print " -C,--chan         Channel codes, default is all\n";
  print " -Q,--qual         Quality indicator, default is best\n";
  print " -s starttime      Specify start time (YYYY/MM/DD HH:MM:SS)\n";
  print " -e endtime        Specify end time (YYYY/MM/DD HH:MM:SS)\n";
  print " -l listfile       Read list of selections from file\n";
  print " -b bfastfile      Read list of selections from BREQ_FAST file\n";
  print " -a user/pass      User and pass when authentication is needed\n";
  print "\n";
  print " -o outfile        Fetch waveform data and write to output file\n";
  print " -sd sacpzdir      Fetch SAC P&Zs and write files to sacpzdir\n";
  print " -rd respdir       Fetch RESP and write files to respdir\n";
  print " -m metafile       Write basic metadata to specified file\n";
  print "\n";
  exit 1;
}

# Check for existence of output directories
if ( $sacpzdir && ! -d "$sacpzdir" ) {
  die "Cannot find SAC P&Zs output directory: $sacpzdir\n";
}
if ( $respdir && ! -d "$respdir" ) {
  die "Cannot find RESP output directory: $respdir\n";
}

# Normalize time strings
if ( $starttime ) {
  my ($year,$month,$mday,$hour,$min,$sec) = split (/[-:,.\s\/T]/, $starttime);
  $starttime = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", $year, $month, $mday, $hour, $min, $sec);
}

if ( $endtime ) {
  my ($year,$month,$mday,$hour,$min,$sec) = split (/[-:,.\s\/T]/, $endtime);
  $endtime = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", $year, $month, $mday, $hour, $min, $sec);
}

# Split authentication credentials into user and password
my ($user,$pass) = split(/\//, $auth);

CHAD, need to use credentials

# An array to hold data selections
my @selections = ();

# Add command line selection to list
if ( defined $net || defined $sta || defined $loc || defined $chan ||
     defined $qual || defined $starttime || defined $endtime ) {
  push (@selections,"$net,$sta,$loc,$chan,$qual,$starttime,$endtime");
}

# Read selection list file
if ( $selectfile ) {
  print STDERR "Reading data selection from list file '$selectfile'\n";
  &ReadSelectFile ($selectfile);
}

# Read BREQ_FAST file
if ( $bfastfile ) {
  print STDERR "Reading data selection from BREQ_FAST file '$bfastfile'\n";
  &ReadBFastFile ($bfastfile);
}

# Report complete data selections
if ( $verbose > 2 ) {
  print STDERR "== Data selections ==\n";
  foreach my $select ( @selections ) {
    print STDERR "    $select\n";
  }
}

# An array to hold channel list and metadata
my @metadata = ();
my %request = (); # Value is metadata range for selection

# Fetch metadata from the station web service
foreach my $selection ( @selections ) {
  my ($snet,$ssta,$sloc,$schan,$squal,$sstart,$send) = split (/,/,$selection);
  &FetchMetaData($snet,$ssta,$sloc,$schan,$squal,$sstart,$send);
}

# Report complete data requests
if ( $verbose > 2 ) {
  print STDERR "== Request list ==\n";
  foreach my $req ( sort keys %request ) {
    print STDERR "    $req (metadata: $request{$req})\n";
  }
}

# Track bytes downloaded
my $totalbytes = 0;
my $datasize = 0;

# Fetch waveform data if output file specified
if ( $outfile ) {
  &FetchWaveformData();

  printf STDERR "Received %s of waveform data\n", sizestring($totalbytes);
}

# Collect SAC P&Zs if output directory specified
&FetchSACPZ if ( $sacpzdir );

# Collect RESP if output directory specified
&FetchRESP if ( $respdir );

# Write metadata to file
if ( $metafile ) {
  printf STDERR "Writing metadata (%d channel epochs) file\n", scalar @metadata if ( $verbose );

  open (META, ">$metafile") || die "Cannot open metadata file '$metafile': $!\n";

  # Print header line
  print META "#net,sta,loc,chan,scale,lat,lon,elev,depth,azimuth,dip,instrument,start,end\n";

  foreach my $channel ( sort @metadata ) {
    my ($net,$sta,$loc,$chan,$start,$end,$lat,$lon,$elev,$depth,$azimuth,$dip) =
      split (/,/, $channel);

    print META "$net,$sta,$loc,$chan,,$lat,$lon,$elev,$depth,$azimuth,$dip,,$start,$end\n";
  }

  close META;
}

print "DONE\n";
## End of main


######################################################################
# ReadSelectFile:
#
# Read selection list file and add entries to the @selections array.
#
# Selection lines are expected to be in the following form:
#
# "Net Sta Loc Chan Qual Start End"
#
# The Net, Sta, Loc and Channel fields are required and can be
# specified as wildcards.
######################################################################
sub ReadSelectFile {
  my $selectfile = shift;

  open (SF, "<$selectfile") || die "Cannot open '$selectfile': $!\n";

  foreach my $line ( <SF> ) {
    chomp $line;
    next if ( $line =~ /^\#/ ); # Skip comment lines

    my ($net,$sta,$loc,$chan,$qual,$start,$end) = split (' ', $line);

    next if ( ! defined $chan );

    # Normalize time strings
    if ( $start ) {
      my ($year,$month,$mday,$hour,$min,$sec) = split (/[-:,.\s\/T]/, $start);
      $start = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", $year, $month, $mday, $hour, $min, $sec);
    }

    if ( $end ) {
      my ($year,$month,$mday,$hour,$min,$sec) = split (/[-:,.\s\/T]/, $end);
      $end = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", $year, $month, $mday, $hour, $min, $sec);
    }

    # Add selection to global list
    push (@selections,"$net,$sta,$loc,$chan,$qual,$start,$end");
  }

  close SF;
} # End of ReadSelectFile()


######################################################################
# ReadBFastFile:
#
# Read BREQ_FAST file and add entries to the @selections array.
#
######################################################################
sub ReadBFastFile {
  my $bfastfile = shift;

  open (BF, "<$bfastfile") || die "Cannot open '$bfastfile': $!\n";

  my $qual = undef;
  my $linecount = 0;
  BFLINE: foreach my $line ( <BF> ) {
    chomp $line;
    $linecount++;
    next if ( ! $line ); # Skip empty lines

    # Capture .QUALTIY header
    if ( $line =~ /^\.QUALITY .*$/ ) {
      ($qual) = $line =~ /^\.QUALITY ([DRQMB])/;
      next;
    }

    next if ( $line =~ /^\./ ); # Skip other header lines

    my ($sta,$net,$syear,$smon,$sday,$shour,$smin,$ssec,$eyear,$emon,$eday,$ehour,$emin,$esec,$count,@chans) = split (' ', $line);

    # Simple validation of BREQ FAST fields
    if ( $sta !~ /^[A-Za-z0-9*?]{1,5}$/ ) {
      print "Unrecognized station code: '$sta', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $net !~ /^[_A-Za-z0-9*?]+$/ ) {
      print "Unrecognized network code: '$net', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $syear !~ /^\d\d\d\d$/ ) {
      print "Unrecognized start year: '$syear', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $smon !~ /^\d{1,2}$/ ) {
      print "Unrecognized start month: '$smon', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $sday !~ /^\d{1,2}$/ ) {
      print "Unrecognized start day: '$sday', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $shour !~ /^\d{1,2}$/ ) {
      print "Unrecognized start hour: '$shour', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $smin !~ /^\d{1,2}$/ ) {
      print "Unrecognized start min: '$smin', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $ssec !~ /^\d{1,2}\.?\d?$/ ) {
      print "Unrecognized start seconds: '$ssec', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $eyear !~ /^\d\d\d\d$/ ) {
      print "Unrecognized end year: '$eyear', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $emon !~ /^\d{1,2}$/ ) {
      print "Unrecognized end month: '$emon', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $eday !~ /^\d{1,2}$/ ) {
      print "Unrecognized end day: '$eday', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $ehour !~ /^\d{1,2}$/ ) {
      print "Unrecognized end hour: '$ehour', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $emin !~ /^\d{1,2}$/ ) {
      print "Unrecognized end min: '$emin', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $esec !~ /^\d{1,2}\.?\d?$/ ) {
      print "Unrecognized end seconds: '$esec', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( $count !~ /^\d+$/ || $count <= 0 ) {
      print "Invalid channel count field: '$count', skipping line $linecount\n" if ( $verbose );
      next;
    }
    if ( scalar @chans <= 0 ) {
      print "No channels specified, skipping line $linecount\n" if ( $verbose );
      next;
    }

    # Extract location ID if present, i.e. if channel count is one less than present
    my $loc = undef;
    $loc = pop @chans if ( scalar @chans == ($count+1) );

    if ( $loc && $loc !~ /^[A-Za-z0-9*?]{1,2}$/ ) {
      print "Unrecognized location ID: '$loc', skipping line $linecount\n" if ( $verbose );
      next;
    }

    foreach my $chan ( @chans ) {
      if ( $chan !~ /^[A-Za-z0-9*?]{3,3}$/ ) {
	print "Unrecognized location ID: '$loc', skipping line $linecount\n" if ( $verbose );
	next BFLINE;
      }
    }

    if ( scalar @chans != $count ) {
      printf "Channel count field ($count) does not match number of channels specified (%d), skipping line $linecount\n",
	scalar @chans if ( $verbose );
      next;
    }

    # Normalize time strings
    my $start = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", $syear, $smon, $sday, $shour, $smin, $ssec);
    my $end = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", $eyear, $emon, $eday, $ehour, $emin, $esec);

    # Add selection to global list for each channel
    foreach my $chan ( @chans ) {
      push (@selections,"$net,$sta,$loc,$chan,$qual,$start,$end");
    }
  }

  close BF;
} # End of ReadBFastFile()


######################################################################
# FetchWaveformData:
#
# Collect waveform data for each entry in the %request hash.  All
# returned data is written to the global output file handle.
#
######################################################################
sub FetchWaveformData {
  # Open output file
  open (OUT, ">$outfile") || die "Cannot open output file '$outfile': $!\n";

  # Create HTTP user agent
  my $ua = LWP::UserAgent->new();
  $ua->agent ($useragent);

  my $count = 0;
  my $total = scalar keys %request;

  print STDERR "Fetching waveform data\n" if ( $verbose );

  foreach my $req ( sort keys %request ) {
    my ($wnet,$wsta,$wloc,$wchan,$wqual,$wstart,$wend) = split (/\|/, $req);
    $count++;

    # Create web service URI
    my $uri = "${waveformservice}?net=$wnet&sta=$wsta&loc=$wloc&cha=$wchan";
    $uri .= "&qual=$wqual" if ( $wqual );
    $uri .= "&starttime=$wstart" if ( $wstart );
    $uri .= "&endtime=$wend" if ( $wend );

    print STDERR "Waveform URI: '$uri'\n" if ( $verbose > 1 );

    print STDERR "Downloading $wnet.$wsta.$wloc.$wchan ($count/$total) :: Received " if ( $verbose );

    $datasize = 0;

    # Fetch waveform data from web service using callback routine
    my $response = $ua->get($uri, ':content_cb' => \&DLCallBack );

    if ( $response->code == 404 ) {
      print STDERR "\b\b\b\b\b\b\b\b\bNo data available\n";
      $request{$req} = undef;
    }
    elsif ( ! $response->is_success() ) {
      print STDERR "\b\b\b\b\b\b\b\b\bError fetching data: "
	. $response->code . " :: " . status_message($response->code) . "\n";
      print STDERR "  URI: '$uri'\n" if ( $verbose > 1 );
      $request{$req} = undef;
    }
    else {
      print STDERR "\n" if ( $verbose );
    }

    # Add data bytes to global total
    $totalbytes += $datasize;
  }

  close OUT;
} # End of FetchWaveformData


######################################################################
# FetchSACPZ:
#
# Fetch SAC Poles and Zeros for each entry in the %request hash with a
# defined value.  The result for each channel is written to a separate
# file in the specified directory.
#
######################################################################
sub FetchSACPZ {
  # Create HTTP user agent
  my $ua = LWP::UserAgent->new();
  $ua->agent ($useragent);

  my $count = 0;
  my $total = 0;
  foreach my $req ( keys %request ) { $total++ if ( defined $request{$req} ); }

  print STDERR "Fetching SAC Poles and Zeros\n" if ( $verbose );

  foreach my $req ( sort keys %request ) {
    # Skip entries with values not set to 1, perhaps no data was fetched
    next if ( ! defined $request{$req} );

    my ($rnet,$rsta,$rloc,$rchan,$rqual,$rstart,$rend) = split (/\|/, $req);
    my ($mstart,$mend) = split (/\|/, $request{$req});
    $count++;

    # Generate output file name and open
    my $sacpzfile = "$sacpzdir/SACPZ.$rnet.$rsta.$rloc.$rchan";
    if ( ! open (OUT, ">$sacpzfile") ) {
      print STDERR "Cannot open output file '$sacpzfile': $!\n";
      next;
    }

    # Use metadata start and end if not specified
    $rstart = $mstart if ( ! $rstart );
    $rend = $mend if ( ! $rend );

    # Create web service URI
    my $uri = "${sacpzservice}?net=$rnet&sta=$rsta&loc=$rloc&cha=$rchan";
    $uri .= "&starttime=$rstart" if ( $rstart );
    $uri .= "&endtime=$rend" if ( $rend );

    print STDERR "SAC-PZ URI: '$uri'\n" if ( $verbose > 1 );

    print STDERR "Downloading $sacpzfile ($count/$total) :: Received " if ( $verbose );

    $datasize = 0;

    # Fetch waveform data from web service using callback routine
    my $response = $ua->get($uri, ':content_cb' => \&DLCallBack );

    if ( $response->code == 404 ) {
      print STDERR "\b\b\b\b\b\b\b\b\bNo data available\n";
    }
    elsif ( ! $response->is_success() ) {
      print STDERR "\b\b\b\b\b\b\b\b\bError fetching data: "
	. $response->code . " :: " . status_message($response->code) . "\n";
      print STDERR "  URI: '$uri'\n" if ( $verbose > 1 );
    }
    else {
      print STDERR "\n" if ( $verbose );
    }

    close OUT;

    # Remove file if no data was fetched
    unlink $sacpzfile if ( $datasize == 0 );
  }
} # End of FetchSACPZ


######################################################################
# FetchRESP:
#
# Fetch SEED RESP for each entry in the %request hash with a value of
# 1.  The result for each channel is written to a separate file in the
# specified directory.
#
######################################################################
sub FetchRESP {
  # Create HTTP user agent
  my $ua = LWP::UserAgent->new();
  $ua->agent ($useragent);

  my $count = 0;
  my $total = 0;
  foreach my $req ( keys %request ) { $total++ if ( defined $request{$req} ); }

  print STDERR "Fetching RESP\n" if ( $verbose );

  foreach my $req ( sort keys %request ) {
    # Skip entries with values not set to 1, perhaps no data was fetched
    next if ( ! defined $request{$req} );

    my ($rnet,$rsta,$rloc,$rchan,$rqual,$rstart,$rend) = split (/\|/, $req);
    my ($mstart,$mend) = split (/\|/, $request{$req});
    $count++;

    # Translate metadata location ID from "--" to blank
    my $ploc = ( $loc eq "--" ) ? "" : $loc;

    # Generate output file name and open
    my $respfile = "$respdir/RESP.$rnet.$rsta.$ploc.$rchan";
    if ( ! open (OUT, ">$respfile") ) {
      print STDERR "Cannot open output file '$respfile': $!\n";
      next;
    }

    # Use metadata start and end if not specified
    $rstart = $mstart if ( ! $rstart );
    $rend = $mend if ( ! $rend );

    # Create web service URI
    my $uri = "${respservice}?net=$rnet&sta=$rsta&loc=$rloc&cha=$rchan";
    $uri .= "&starttime=$rstart" if ( $rstart );
    $uri .= "&endtime=$rend" if ( $rend );

    print STDERR "RESP URI: '$uri'\n" if ( $verbose > 1 );

    print STDERR "Downloading $respfile ($count/$total) :: Received " if ( $verbose );

    $datasize = 0;

    # Fetch waveform data from web service using callback routine
    my $response = $ua->get($uri, ':content_cb' => \&DLCallBack );

    if ( $response->code == 404 ) {
      print STDERR "\b\b\b\b\b\b\b\b\bNo data available\n";
    }
    elsif ( ! $response->is_success() ) {
      print STDERR "\b\b\b\b\b\b\b\b\bError fetching data: "
	. $response->code . " :: " . status_message($response->code) . "\n";
      print STDERR "  URI: '$uri'\n" if ( $verbose > 1 );
    }
    else {
      print STDERR "\n" if ( $verbose );
    }

    close OUT;

    # Remove file if no data was fetched
    unlink $respfile if ( $datasize == 0 );
  }
} # End of FetchRESP


######################################################################
# DLCallBack:
#
# A call back for LWP downloading.
#
# Write received data to output file, tally up the received data size
# and print and updated (overwriting) byte count string.
######################################################################
sub DLCallBack {
  my ($data, $response, $protocol) = @_;
  print OUT $data;
  $datasize += length($data);

  if ( $verbose ) {
    printf (STDERR "%-10.10s\b\b\b\b\b\b\b\b\b\b", sizestring($datasize));
  }
}


######################################################################
# FetchMetaData:
#
# Collect metadata and expand wildcards for selected data set.
#
# Resulting metadata is placed in the global @metadata array with each
# entry taking the following form:
#   "net,sta,loc,chan,start,end,lat,lon,elev,depth,azimuth,dip"
#
# In addition, an entry for the unique NSLCQ time-window is added to
# the %request hash, used later to request data.  The value of the
# request hash entries is maintained to be the range of Channel epochs
# that match the time selection.
#
######################################################################
sub FetchMetaData {
  my ($rnet,$rsta,$rloc,$rchan,$rqual,$rstart,$rend) = @_;

  # Convert request start/end times to epoch times
  my $rstartepoch = str2time ($rstart);
  my $rendepoch = str2time ($rend);

  # Create web service URI
  my $uri = "${metadataservice}?channels=true";
  $uri .= "&network=$rnet" if ( $rnet );
  $uri .= "&station=$rsta" if ( $rsta );
  $uri .= "&location=$rloc" if ( $rloc );
  $uri .= "&channel=$rchan" if ( $rchan );
  if ( $rstart && $rend ) {
    my ($startdate) = $rstart =~ /^(\d{4,4}-\d{1,2}-\d{1,2}).*$/;
    my ($enddate) = $rend =~ /^(\d{4,4}-\d{1,2}-\d{1,2}).*$/;
    $startdate =~ s/-/\//g;
    $enddate =~ s/-/\//g;

    $uri .= "&timewindow=${startdate}-${enddate}";
  }

  print STDERR "Metadata URI: '$uri'\n" if ( $verbose > 1 );

  print STDERR "Fetching metadata... " if ( $verbose );

  # Create HTTP user agent
  my $ua = LWP::UserAgent->new();
  $ua->agent ($useragent);

  # Fetch metadata from web service
  my $response = $ua->get($uri);

  if ( ! $response->is_success() ) {
    print STDERR "Error fetching data '$uri'\n";
    return;
  }

  # Create stream oriented XML parser instance
  use XML::SAX;
  my $parser = new XML::SAX::ParserFactory->parser( Handler => MDSHandler->new );

  my $totalepochs = 0;

  # Parse XML metadata
  $parser->parse_string ($response->content);

  print STDERR "Done.\n" if ( $verbose );

  print "Received metadata for $totalepochs channel epochs\n";


  ## Beginning of SAX MDSHandler, event-based streaming XML parsing
  package MDSHandler;
  use base qw(XML::SAX::Base);
  use HTTP::Date;
  use Data::Dumper;

  my $inchannel = 0;
  my $inazimuth = 0;
  my $indip = 0;
  my ($net,$sta,$loc,$chan,$start,$end,$lat,$lon,$elev,$depth,$azimuth,$dip) = (undef) x 12;

  #print Dumper ($element);

  sub start_element {
    my ($self,$element) = @_;

    if ( $element->{Name} eq "Channel" ) {
      ($net,$sta,$loc,$chan,$start,$end,$lat,$lon,$elev,$depth,$azimuth,$dip) = (undef) x 12;

      $net = $element->{Attributes}->{'{}networkCode'}->{Value};
      $sta = $element->{Attributes}->{'{}stationCode'}->{Value};
      $loc = $element->{Attributes}->{'{}locationCode'}->{Value};
      $chan = $element->{Attributes}->{'{}channelCode'}->{Value};
      $inchannel = 1;
    }

    if ( $inchannel && $element->{Name} eq "Epoch" ) {
      $start = $element->{Attributes}->{'{}start'}->{Value};;
      $end = $element->{Attributes}->{'{}end'}->{Value};;
    }

    if ( $inchannel && $element->{Name} eq "Latitude" ) {
      $lat = $element->{Attributes}->{'{}value'}->{Value};
    }

    if ( $inchannel && $element->{Name} eq "Longitude" ) {
      $lon = $element->{Attributes}->{'{}value'}->{Value};
    }

    if ( $inchannel && $element->{Name} eq "Elevation" ) {
      $elev = $element->{Attributes}->{'{}value'}->{Value};
    }

    if ( $inchannel && $element->{Name} eq "Depth" ) {
      $depth = $element->{Attributes}->{'{}value'}->{Value};
    }

    if ( $inchannel && $element->{Name} eq "Azimuth" ) {
      $azimuth = $element->{Attributes}->{'{}value'}->{Value};
      $inazimuth = 1;
    }

    if ( $inchannel && $element->{Name} eq "Dip" ) {
      $dip = $element->{Attributes}->{'{}value'}->{Value};
      $indip = 1;
    }
  }

  sub end_element {
    my ($self,$element) = @_;

    if ( $element->{Name} eq "Channel" ) {
      ($net,$sta,$loc,$chan) = (undef) x 4;
      $inchannel = 0;
    }

    if ( $inchannel && $element->{Name} eq "Epoch" ) {
      my $startepoch = str2time ($start);
      my $endepoch = str2time ($end);

      # Check that Channel Epoch is within request window, allow for open window requests
      if ( ( ! $rstartepoch || ! $endepoch || ($rstartepoch <= $endepoch) ) &&
	   ( ! $rendepoch || ($rendepoch >= $startepoch) ) )
	{
	  $totalepochs++;

	  # Translate metadata location ID to "--" if it's spaces
	  my $dloc = ( $loc eq "  " ) ? "--" : $loc;

	  # Cleanup start and end strings
	  ($start) = $start =~ /^(\d{4,4}[-\/,:]\d{1,2}[-\/,:]\d{1,2}[-\/,:T]\d{1,2}[-\/,:]\d{1,2}[-\/,:]\d{1,2}).*/;
	  ($end) = $end =~ /^(\d{4,4}[-\/,:]\d{1,2}[-\/,:]\d{1,2}[-\/,:T]\d{1,2}[-\/,:]\d{1,2}[-\/,:]\d{1,2}).*/;

	  # Push channel epoch metadata into storage array
	  push (@metadata, "$net,$sta,$dloc,$chan,$start,$end,$lat,$lon,$elev,$depth,$azimuth,$dip");

	  # Put entry into request hash, value is the widest range of channel epochs
	  if ( ! exists  $request{"$net|$sta|$dloc|$chan|$rqual|$rstart|$rend"} ) {
	    $request{"$net|$sta|$dloc|$chan|$rqual|$rstart|$rend"} = "$start|$end";
	  }
	  else {
	    # Track widest metadata start and end range
	    my ($vstart,$vend) = split (/\|/, $request{"$net|$sta|$dloc|$chan|$rqual|$rstart|$rend"});
	    $vstart = $start if ( $startepoch < str2time ($vstart) );
	    $vend = $end if ( $endepoch > str2time ($vend) );
	    $request{"$net|$sta|$dloc|$chan|$rqual|$rstart|$rend"} = "$vstart|$vend";
	  }
	}

      # Reset Epoch level fields
      ($start,$end,$lat,$lon,$elev,$depth,$azimuth,$dip) = (undef) x 12;
    }

    if ( $inchannel && $element->{Name} eq "Azimuth" ) {
      $inazimuth = 0;
    }

    if ( $inchannel && $element->{Name} eq "Dip" ) {
      $indip = 0;
    }
  }

  sub characters {
    my ($self,$element) = @_;

    if ( $inazimuth ) {
      $azimuth = $element->{Data};
    }

    if ( $indip ) {
      $dip = $element->{Data};
    }
  }
} # End of FetchMetaData()


######################################################################
# sizestring (bytes):
#
# Return a clean size string for a given byte count.
######################################################################
sub sizestring { # sizestring (bytes)
  my $bytes = shift;

  if ( $bytes < 1000 ) {
    return sprintf "$bytes Bytes";
  }
  elsif ( ($bytes / 1024) < 1000 ) {
    return sprintf "%.1f KB", $bytes / 1024;
  }
  elsif ( ($bytes / 1024 / 1024) < 1000 ) {
    return sprintf "%.1f MB", $bytes / 1024 / 1024;
  }
  elsif ( ($bytes / 1024 / 1024 / 1024 / 1024) < 1000 ) {
    return sprintf "%.1f GB", $bytes / 1024 / 1024 / 1024 / 1024;
  }
  elsif ( ($bytes / 1024 / 1024 / 1024 / 1024 / 1024) < 1000 ) {
    return sprintf "%.1f TB", $bytes / 1024 / 1024 / 1024 / 1024 / 1024;
  }
  else {
    return "";
  }
} # End of sizestring()
