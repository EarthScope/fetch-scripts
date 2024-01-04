Convenient access to seismological data via FDSN and other web services.

The scripts are written in Perl and Python and should run on most systems.

## Overview of scripts

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

<!-- GitHub corner from https://github.com/tholman/github-corners -->
<a href="https://github.com/EarthScope/fetch-scripts" class="github-corner" aria-label="View source on GitHub"><svg width="80" height="80" viewBox="0 0 250 250" style="fill:#70B7FD; color:#fff; position: absolute; top: 0; border: 0; right: 0;" aria-hidden="true"><path d="M0,0 L115,115 L130,115 L142,142 L250,250 L250,0 Z"></path><path d="M128.3,109.0 C113.8,99.7 119.0,89.6 119.0,89.6 C122.0,82.7 120.5,78.6 120.5,78.6 C119.2,72.0 123.4,76.3 123.4,76.3 C127.3,80.9 125.5,87.3 125.5,87.3 C122.9,97.6 130.6,101.9 134.4,103.2" fill="currentColor" style="transform-origin: 130px 106px;" class="octo-arm"></path><path d="M115.0,115.0 C114.9,115.1 118.7,116.5 119.8,115.4 L133.7,101.6 C136.9,99.2 139.9,98.4 142.2,98.6 C133.8,88.0 127.5,74.4 143.8,58.0 C148.5,53.4 154.0,51.2 159.7,51.0 C160.3,49.4 163.2,43.6 171.4,40.1 C171.4,40.1 176.1,42.5 178.8,56.2 C183.1,58.6 187.2,61.8 190.9,65.4 C194.5,69.0 197.7,73.2 200.1,77.6 C213.8,80.2 216.3,84.9 216.3,84.9 C212.7,93.1 206.9,96.0 205.4,96.6 C205.1,102.4 203.0,107.8 198.3,112.5 C181.9,128.9 168.3,122.5 157.7,114.1 C157.9,116.9 156.7,120.9 152.7,124.9 L141.0,136.5 C139.8,137.7 141.6,141.9 141.8,141.8 Z" fill="currentColor" class="octo-body"></path></svg></a><style>.github-corner:hover .octo-arm{animation:octocat-wave 560ms ease-in-out}@keyframes octocat-wave{0%,100%{transform:rotate(0)}20%,60%{transform:rotate(-25deg)}40%,80%{transform:rotate(10deg)}}@media (max-width:500px){.github-corner:hover .octo-arm{animation:none}.github-corner .octo-arm{animation:octocat-wave 560ms ease-in-out}}</style>
