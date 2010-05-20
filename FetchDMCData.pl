#!/usr/bin/perl
#
# FetchDMCData:
#
# Fetch bulk data from the DMC web interfaces.  Data selection can be
# specified in terms of network, station, location, channel, start
# time and end time.
#
# All received data is written to a single output file.  Optionally
# the basic metadata can be written to a file as a simple ASCII list.
#
# 2010.140:
#  - Initial version
#
# Author: Chad Trabant, IRIS Data Managment Center

# To Do:
# Transition to new metadata service
# Check other error status?
# Parallelize waveform fetching?
# Restartable?  Check data already downloaded?

use strict;
use File::Basename;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Status qw(status_message);
use Data::Dumper;

my $version  = "2010.140";

# Web service for metadata
my $metadataservice = 'http://www.iris.edu/mds/';

# Web service for waveform data
my $waveformservice = 'http://www.iris.edu/ws/dataselect/query';

# HTTP UserAgent reported to web services
my $useragent = "FetchDMCData/$version";

my $usage     = undef;
my $verbose   = undef;
my $pretend   = undef;

my $net        = undef;
my $sta        = undef;
my $loc        = undef;
my $chan       = undef;
my $qual       = undef;
my $starttime  = undef;
my $endtime    = undef;
my $selectfile = undef;
my $bfastfile  = undef;
my $metafile   = undef;
my $outfile    = undef;

# Parse command line arguments
Getopt::Long::Configure("bundling");
my $getoptsret = GetOptions ( 'help|usage|h'   => \$usage,
                              'verbose|v+'     => \$verbose,
                              'pretend|p'      => \$pretend,
                              'net|N=s'        => \$net,
                              'sta|S=s'        => \$sta,
                              'loc|L=s'        => \$loc,
                              'chan|C=s'       => \$chan,
                              'qual|Q=s'       => \$qual,
			      'starttime|s=s'  => \$starttime,
			      'endtime|e=s'    => \$endtime,
			      'selectfile|l=s' => \$selectfile,
			      'bfastfile|b=s'  => \$bfastfile,
			      'metafile|m=s'   => \$metafile,
			      'outfile|o=s'    => \$outfile,
			    );

my $required =  ( defined $net || defined $sta ||
		  defined $loc || defined $chan ||
		  defined $starttime || defined $endtime ||
		  defined $selectfile || defined $bfastfile );

if ( ! $getoptsret || $usage || ! $outfile || ! $required ) {
  my $script = basename($0);
  print "$script: collect waveform data from the IRIS DMC (version $version)\n\n";
  print "Usage: $script [options]\n\n";
  print " Options:\n";
  print " -v                Increase verbosity, may be specified multiple times\n";
  print " -p                Pretend, do everything but request waveform data\n";
  print " -V,--vnet         Virtual network, superseded by network selection\n";
  print " -N,--net          Network code, default is all\n";
  print " -S,--sta          Station code, default is all\n";
  print " -L,--loc          Location ID, default is all\n";
  print " -C,--chan         Channel codes, default is all\n";
  print " -Q,--qual         Quality indicator, default is best\n";
  print " -s starttime      Specify start time (YYYY/MM/DD HH:MM:SS)\n";
  print " -e endtime        Specify end time (YYYY/MM/DD HH:MM:SS)\n";
  print " -l listfile       Read list of selections from file\n";
  print " -b bfastfile      Read list of selections from BREQ_FAST file\n";
  print " -m metafile       Write basic metadata to specified file\n";
  print " -o outfile        Specify output file, required\n";
  print "\n";
  exit 1;
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
my @channels = ();
my %waveform = ();

# Fetch metadata from the station web service
foreach my $selection ( @selections ) {
  my ($snet,$ssta,$sloc,$schan,$squal,$sstart,$send) = split (/,/,$selection);
  &GetMetaData($snet,$ssta,$sloc,$schan,$squal,$sstart,$send);
}

# Report complete data requests
if ( $verbose > 2 ) {
  print STDERR "== Data requests ==\n";
  foreach my $req ( sort keys %waveform ) {
    print STDERR "    $req\n";
  }
}

# Track bytes downloaded
my $totalbytes = 0;
my $datasize = 0;

# Collect waveform data if not pretending
if ( ! $pretend ) {
  # Open output file
  open (OUT, ">$outfile") || die "Cannot open output file '$outfile': $!\n";

  # Fetch waveform data from the waveform web service
  &GetWaveformData();

  close OUT;
}

printf STDERR "Received %s of waveform data\n", sizestring($totalbytes);

if ( $metafile ) {
  print STDERR "Writing metadata file\n" if ( $verbose );

  open (META, ">$metafile") || die "Cannot open metadata file '$metafile': $!\n";

  # Print header line
  print META "#net,sta,loc,chan,scale,lat,lon,elev,depth,azimuth,dip,instrument,start,end\n";

  foreach my $channel ( sort @channels ) {
    my ($net,$sta,$loc,$chan,$start,$end,$lat,$lon,$elev,$depth,$azimuth,$dip) =
      split (/,/, $channel);

    print META "$net,$sta,$loc,$chan,,$lat,$lon,$elev,$depth,$azimuth,$dip,,$start,$end\n";
  }

  close META;
}
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
# GetWaveformData:
#
# Collect waveform data for each entry in the %waveform hash.  All
# returned data is written to the global output file handle.
#
######################################################################
sub GetWaveformData {
  # Create HTTP user agent
  my $ua = LWP::UserAgent->new();
  $ua->agent ($useragent);

  my $count = 0;
  my $total = scalar keys %waveform;

  foreach my $request ( sort keys %waveform ) {
    my ($wnet,$wsta,$wloc,$wchan,$wqual,$wstart,$wend) = split (/,/, $request);
    $count++;

    # Create web service URI
    my $uri = "${waveformservice}?net=$wnet&sta=$wsta&loc=$wloc&cha=$wchan";
    $uri .= "&qual=$wqual" if ( defined $wqual );
    $uri .= "&starttime=$wstart" if ( defined $wstart );
    $uri .= "&endtime=$wend" if ( defined $wend );

    print STDERR "Waveform URI: '$uri'\n" if ( $verbose > 1 );

    print STDERR "Downloading $wnet.$wsta.$wloc.$wchan ($count/$total) :: Received " if ( $verbose );

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

    # Add data bytes to global total
    $totalbytes += $datasize;
  }

} # End of GetWaveformData


######################################################################
# DLCallBack:
#
# A call back for LWP downloading.
#
# Write received data to putput file, tally up the received data size
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
# GetMetaData:
#
# Collect metadata and expand wildcards for selected data set.
#
# Resulting metadata is placed in the global @channels array with each
# entry taking the following form:
#   "net,sta,loc,chan,start,end,lat,lon,elev,depth,azimuth,dip"
#
# In addition, an entry for the unique NSLCQ time-window is added to
# the %waveform hash, which is used to request waveform data.
#
######################################################################
sub GetMetaData {
  my ($mnet,$msta,$mloc,$mchan,$mqual,$mstart,$mend) = @_;

  # Create web service URI
  my $uri = "${metadataservice}?channels=true";
  $uri .= "&network=$mnet" if ( $mnet );
  $uri .= "&station=$msta" if ( $msta );
  $uri .= "&location=$mloc" if ( $mloc );
  $uri .= "&channel=$mchan" if ( $mchan );
  if ( $mstart && $mend ) {
    my ($startdate) = $mstart =~ /^(\d{4,4}-\d{1,2}-\d{1,2}).*$/;
    my ($enddate) = $mend =~ /^(\d{4,4}-\d{1,2}-\d{1,2}).*$/;
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
      $totalepochs++;

      # Translate metadata location ID to "--" if it's spaces
      my $dloc = ( $loc eq "  " ) ? "--" : $loc;

      # Push channel epoch metadata into storage array and chanset hash
      push (@channels, "$net,$sta,$dloc,$chan,$start,$end,$lat,$lon,$elev,$depth,$azimuth,$dip");
      $waveform{"$net,$sta,$dloc,$chan,$mqual,$mstart,$mend"} = 1;

      ($start,$end) = (undef) x 2;
      ($lat,$lon,$elev,$depth ) = (undef) x 4;
      ($azimuth,$dip) = (undef) x 2;
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
} # End of GetMetaData()


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
