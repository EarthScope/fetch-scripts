## Executing the scripts

After downloading the scripts they can be executed from the command line either by explicitly invoking Perl or by making the scripts executable and letting the OS run Perl for you. To explicitly invoke Perl to execute a script type the following:

```Console
$ perl FetchData
```

To make a script executable on the Unix-like operating system use the `chmod` command, after which the script can be run like any other program from the command line:

```Console
$ chmod +x FetchData
$ ./FetchData
```

## Requesting miniSEED and simple metadata using `FetchData`

To request the first hour of the year 2011 for BHZ channels from GSN stations, execute the following command:

```Console
$ FetchData -N _GSN -C BHZ -s 2011-01-01T00:00:00 -e 2011-01-01T01:00:00 -o GSN.mseed -m GSN.metadata
```

Note that the network specification used is a virtual network code; regular network codes may also be specified. The start and end times are specified in an ISO defined format, with a capital 'T' separating the date from the time. Commas are also permissible to separate the date and time components.

The received miniSEED will be saved to the `GSN.mseed` file and simple ASCII metadata will be saved to the `GSN.metadata` file. These two files can be used to convert the data to SAC format with the [mseed2sac](https://github.com/EarthScope/mseed2sac):

```Console
$ mseed2sac GSN.mseed -m GSN.metadata
```

## Requesting event information for magnitude 6+ events within 10 degrees of location

To request magnitude 6+ events within 20 degrees of the main shock of the Tohoku-Oki, Japan Earthquake on or after March 11th 2011, execute the following command:

```Console
$ FetchEvent -s 2011-03-11 --radius 38.2:142.3:20 --mag 6
```

h2. Requesting data from multiple data centers (federating)

If the `-F` option is used with FetchData (version 2015.014 and later) it will first submit the request to the IRIS Federator to determine which data centers have data matching the criteria, then it will make a request to each data center to retrieve the miniSEED.

For example, the request 1+ hour of global LHZ channels for the 1995 Mw 8.0 Chile earthquake a command like this may be suitable:

```Console
$ FetchData -F -C LHZ -s 1995-7-30T05:11:23 -e 1995-7-30T06:30:00 -o event.mseed -m event.meta
```

*Note*: not all FDSN data centers support the direct retrieval of metadata in SEED RESP and SAC PZ formats, consequently requesting such information when federating the request will usually fail with some data centers.  Simple metadata, as saved by the *-m* option, should always work as it only relies on a compliant fdsnws-station service.

## Wildcards and lists

The network, station, location and channel selections may include both wildcards and lists. The supported wildcards are *, meaning zero to many characters, and ?, meaning a single character. Example wildcard usage: 'BH*' and 'L??'. A list is specified as simple comma-separated values, for example: 'BHE,BHN,BHZ'. Illustrating both of these features using command line selections (the same applies to the selection list file):

```Console
$ FetchData -N IU -S ANMO,COLA -C 'BH*,LH*' -s 2011-01-01T00:00:00 -e 2011-01-01T01:00:00 -o ANMO-COLA.mseed
```

Note that the wildcard characters usually need to be quoted to avoid them being interpreted by the shell.

## Selecting data by region

The FetchData script allows data selection by geographic region in two ways: 1) specifying minimum and maximum latitude and/or longitude and 2) specifying a point and a maximum radius in degrees including the optional specification of a minimum radius to define a circular range from a point. For example, to request 10 minutes of miniSEED data for all BHZ channels available within 10 degrees of the M5 2010 Ottowa, Canada earthquake at latitude 45.88 and longitude -75.48 try the follow:

```Console
$ FetchData -radius 45.88:-75.48:10 -m OttowaM5.meta -o OttowaM5.mseed -C BHZ -s 2010-06-23T17:41 -e 2010-06-23T17:51
```

## Large data selections

To specify many selections or combinations not possible using the command line options the Fetch scripts can read a file containing either a simple ASCII selection list or a BREQ_FAST formatted request.

For a file containing a selection list use the -l option:

```Console
$ FetchData -l myselection.txt -o mydata.mseed
```

The expected selection list format is documented [below](#Selection-List-Format).

For a file containing a legacy BREQ_FAST-formatted request use the -b option:

```Console
$ FetchData -b mybreqfast.txt -o mydata.mseed
```

## Reducing data segmentation

Specific to FetchData are two options for limiting the level of segmented data returned:

* `-msl _length_` :: Specify minimum segment length in seconds, no segments shorter than length will be returned
* `-lso` :: Return only the longest segment from each distinct channel

Warning: These options limit the data returned, using them incorrectly or when data is very gappy can result in no returned data. These options do not fill gaps. 

## Requesting SEED RESP or SAC Poles and Zeros files with miniSEED data

The `FetchData` script can collect the SEED RESP or SAC Poles and Zeros matching the requested data at the same time it collects the time series data. An individual RESP and/or SACPZ file is created for each channel requested. You must specify an existing directory to which to write the files.

To collect SEED RESP with data use the -rd option (using a dot for the current directory):

```Console
$ FetchData -S COLA -C BHZ -s 2011-01-01T00:00:00 -e 2011-01-01T01:00:00 -o COLA.mseed -rd .
```

To collect SAC Poles and Zeros with data use the `-sd` option (using a dot for the current directory):

```Console
$ FetchData -S COLA -C BHZ -s 2011-01-01T00:00:00 -e 2011-01-01T01:00:00 -o COLA.mseed -sd .
```

## Selecting a blank (space-space) SEED location ID

Many SEED location IDs are blank. Since these location IDs are stored as a 2-character field in the SEED format a blank location ID means the field is actually 2 ASCII space characters. To specifically select blank location IDs space characters may be used. Because spaces can sometimes be troublesome to provide exactly in scripts, in selection files, etc. the web services will also accept IDs specified as '--' (two dashes) which will be mapped to spaces.

## Selection List Format

All of the Fetch scripts which request information about time series channels will accept a selection list to define the request.

A selection list is simply an ASCII file where each line specifies a complete data selection containing the following space-separated values:

```
Network Station Location Channel StartTime EndTime
```

For example, a selection list for a small time window for BHZ channels from the selected GSN stations would be:

```
II AAK 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
II ABKT 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
II ABPO 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
II ALE 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
II ARU 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
II ASCN 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
II BFO 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
II BORG 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU ADK 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU AFI 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU ANMO 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU ANTO 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU BBSR 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU BILL 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU CASY 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU CCM 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU CHTO 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
IU COLA 00 BHZ 2011-01-01T00:00:00 2011-01-01T01:00:00
```

With this selection list saved to a file name `myselection.txt` it can be used, for example, like this:

```Console
$ FetchData -l myselection.txt -o mydata.mseed
```

