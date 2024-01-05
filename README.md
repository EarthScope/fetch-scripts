# fetch-scripts - command line access to seismic data

Convenient access to seismological data via FDSN and other web services.

The scripts are written in Perl and Python and should run on most systems.

## The scripts

**[FetchData](FetchData)** (Perl) - Fetch time series and optionally, related metadata, matching SAC Poles and Zeros and matching SEED RESP files. Time series data are returned in miniSEED format, metadata is saved as a simple ASCII list.

**[FetchEvent](FetchEvent)** (Perl) - Fetch event parameters and print simple text summary.  Works with any fdsnws-event service.

**[FetchSyn](FetchSyn)** (Python) - Fetch synthetics seismograms from the [EarthScope Syngine](https://service.iris.edu/irisws/syngine/1/) service.  See [FetchSyn usage](docs/fetchsyn.md).

## Quick start

1. Download the latest version of desired scripts at the links above
1. Make the scripts executable (e.g 'chmod +x FetchData') if needed
1. Run script to print usage message

## Documentation and examples

Further description and example usage can be found [in the tutorial](docs/tutorial.md)

## Using the scripts with other data centers

See documentation on [using the scripts with other data centers](docs/other-centers.md)

## Perl requirements

The Perl scripts should run with any relatively recent Perl interpreter.  In some cases, particularly for older Perl releases, you might need to install some required modules, namely **XML::SAX** and **Bundle::LWP** (libwww-perl).  The procedure to install these modules is system dependent, for most Unix/Linux OSes they can be installed using the package management system.  In addition to Perl only network access to the EarthScope web services is needed.

For large data requests installing the **XML::SAX::ExpatXS** Perl module will significantly increase the parsing speed of XML metadata used by all scripts.

## Running the Perl scripts on Windows

Most Windows computers do not have Perl by default and one must be installed.  Any distribution of Perl should work as long as the required modules are included.  The [Strawberry Perl](http://strawberryperl.com/) distribution for Windows is known to work and is recommended.

Once installed, the Fetch scripts may be run from a command prompt (e.g. Windows PowerShell) by typing **perl** followed by the name of the script.  For example:

```Console
PS C:\Users\username\Downloads> perl .\FetchData
```

**Note**: the Fetch scripts are command-line oriented with no GUI, double-clicking them in Explorer using does not do anything useful.

## Copyright and License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Copyright (c) 2018 EarthScope Consortium

{% include_relative docs/github-corner.html %}
