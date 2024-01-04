# Command line scripts for accessing data via FDSN and other web services

The scripts are written in Perl and Python and should run on most systems
with that language support.

## Overview of scripts

**FetchData** (Perl) - Fetch time series and optionally, related metadata, matching SAC Poles and Zeros and matching SEED RESP files. Time series data are returned in miniSEED format, metadata is saved as a simple ASCII list.

**FetchMetadata** (Perl) - Fetch station metadata and output simple text. Optionally, the XML returned by the service can be saved.  Works with any fdsnws-station service.

**FetchEvent** (Perl) - Fetch event parameters and print simple text summary.  Works with any fdsnws-event service.

**FetchSyn** (Python) - Fetch synthetics seismograms from the [EarthScope Syngine](https://service.iris.edu/irisws/syngine/1/) service.

## Documentation and examples

Further description and example usage can be found [in the documentation](https://earthscope.github.io/fetch-scripts)
