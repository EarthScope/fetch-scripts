## Python dependencies

The requests library is needed.  Currently `FetchSyn` is compatible with python 2 & 3.

## Executing the scripts

After downloading the scripts they can be executed from the command line either by explicitly invoking python or by making the scripts executable and installing the path to python in the first line.  To explicitly invoke python to execute a script type the following:

```Console
$ python FetchSyn
```

## Help menu to list parameters

To access the help menu, which lists all input parameters:

```Console
$ FetchSyn -u
```

## Examples

To generate a synthetic for IU.ANMO for the Tohoku earthquake using it's GCMT origin and moment tensor:

```Console
$ FetchSyn -N IU -S ANMO -evid GCMT:M201103110546A
```

Same request, but add station KIP and make the source depth 35km and return the vertical (Z), radial (R) and transverse (T) components rather than the default ZNE components:

```Console
$ FetchSyn -N IU -S ANMO,KIP -C ZRT -evid GCMT:M201103110546A -sdepm 35000
```


Same request, but:
* include all stations in the virtual network _GSN
* use a different [model](http://ds.iris.edu/ds/products/syngine/#models)
* change the sample rate to 0.05 sps
* make the output miniseed rather than saczip
* return velocity not the default (displacement)
* cut the traces to 10 seconds before P
* make traces 300 seconds in duration
* add user-agent identification (helps DMC & helps you if there are problems)

```Console
$ FetchSyn -N _GSN -model prem_a_20s -dt 0.05 -format mseed -units velocity -start P-10 -end 300 -A "Joe Seismologist" -C ZRT -evid GCMT:M201103110546A -sdepm 35000
```

### Manually input source and use a file with a list of receivers

Example using a text file with receiver names.  Each line of the receiver file is an example of valid formatting.  The networkcode, stationcode, locationcode in the later lines is optional.

rec.txt:
```Console
IU ANMO 
II *
-89 -179
-89 -178 S0002
-89 -177 N2 S0003 L2
```

Manually input the origin using a double couple source (strike,dip,rake[,optional_scalar_moment_in_NM])

```Console
$ FetchSyn -recfile rec.txt -origin 2011,03,11,05,46,24 -slat 38.3 -slon 142.3 -sdepm 24400 -dc 203,10,88,5.3e22 -C Z
```

