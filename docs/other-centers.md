## Overview

The Fetch scripts may be used to access information at other data centers as long as the service interfaces are compatible with the versions offered by EarthScope.  Many of the services are [standardized by the FDSN](https://fdsn.org/webservices/) and offered by other data centers.  By default, the scripts are configured to fetch information from EarthScope.  Alternate locations of service interfaces may be specified.

## Specifying alternate service locations using environment variables

Default service locations can be overridden by setting the following environment variables:

**SERVICEBASE** = the base URI of the service(s) to use (http://service.iris.edu/)

**TIMESERIESWS** = complete URI of service (http://service.iris.edu/fdsnws/dataselect/1)

**METADATAWS** = complete URI of service (http://service.iris.edu/fdsnws/station/1)

**EVENTWS** = complete URI of service (http://service.iris.edu/fdsnws/event/1)

**SACPZWS** = complete URI of service (http://service.iris.edu/irisws/sacpz/1)

**RESPWS** = complete URI of service (http://service.iris.edu/irisws/resp/1)

The *SERVICEBASE* variable will be used for all services if set.  The other, service-specific variables, are explicit paths to each service.  The service-specific variables are useful if the path after the hostname is different than used by the IRIS DMC, or if users wish to use services at different data centers (e.g. events from one center and time series from another).

## Specifying alternate service locations using command line options

Default service locations can be overridden by specifying the following command line options:

`-timeseriesws`

`-metadataws`

`-eventws`

`-sacpzws`

`-respws`

Obviously, each script only accepts the argument(s) appropriate for its operation.

## Wrapper scripts for other accessing other data centers

Simple shell wrapper scripts can be created to redirect access to alternate locations.  For example:

**FetchData-IRISDMC**:
```bash
#!/bin/bash

# Set servce base path, change to your own service host
SERVICEBASE="http://service.iris.edu"

# Set all service specific locations using the service base
TIMESERIESWS="${SERVICEBASE}/fdsnws/dataselect/1"
METADATAWS="${SERVICEBASE}/fdsnws/station/1"
EVENTWS="${SERVICEBASE}/fdsnws/event/1"
SACPZWS="${SERVICEBASE}/irisws/sacpz/1"
RESPWS="${SERVICEBASE}/irisws/resp/1"

export SERVICEBASE TIMESERIESWS METADATAWS EVENTWS SACPZWS RESPWS

exec FetchData "$@"
```

The above script can be customized to redirect all traffic to an alternate data center by replacing the URLs with another location.


