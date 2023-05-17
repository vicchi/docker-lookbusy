# docker-lookbusy

A lightweight multi-architecture Docker image for [lookbusy](http://www.devin.com/lookbusy/).

The following platform architectures are currently available:

* `linux/arm/v7`
* `linux/arm64/v8`
* `linux/amd64`

## lookbusy

Lookbusy is a simple application for generating synthetic load on a Linux system. It can generate fixed, predictable loads on CPUs, keep chosen amounts of memory active, and generate disk traffic in any amounts you need.

![lookbusy](http://www.devin.com/lookbusy/logo.png)

The source project's website is [here](http://www.devin.com/lookbusy/).

## Build

Copy `.env.sample` to `.env` and edit, adding your GitHub username and Personal Access Token; this
repo assumes pushing to the GitHub Container Registry at `ghcr.io`.

```
$ make build
```

## Starting Lookbusy with Docker

```
docker run ghcr.io/vicchi/lookbusy:1.4.0 --cpu-mode=curve --cpu-util=10-15
```

To display all `lookbusy` command line options: 

```
$ docker run --rm ghcr.io/vicchi/lookbusy:1.4.0
usage: lookbusy [ -h ] [ options ]
General options:
  -h, --help           Commandline help (you're reading it)
  -v, --verbose        Verbose output (may be repeated)
  -q, --quiet          Be quiet, produce output on errors only
CPU usage options:
  -c, --cpu-util=PCT,  Desired utilization of each CPU, in percent (default
      --cpu-util=RANGE   50%).  If 'curve' CPU usage mode is chosen, a range
                         of the form MIN-MAX should be given.
  -n, --ncpus=NUM      Number of CPUs to keep busy (default: autodetected)
  -r, --cpu-mode=MODE  Utilization mode ('fixed' or 'curve', see lookbusy(1))
  -p, --cpu-curve-peak=TIME
                       Offset of peak utilization within curve period, in
                         seconds (append 'm', 'h', 'd' for other units)
  -P, --cpu-curve-period=TIME
                       Duration of utilization curve period, in seconds (append
		       'm', 'h', 'd' for other units)
Memory usage options:
  -m, --mem-util=SIZE   Amount of memory to use (in bytes, followed by KB, MB,
                         or GB for other units; see lookbusy(1))
  -M, --mem-sleep=TIME Time to sleep between iterations, in usec (default 1000)
Disk usage options:
  -d, --disk-util=SIZE Size of files to use for disk churn (in bytes,
                         followed by KB, MB, GB or TB for other units)
  -b, --disk-block-size=SIZE
                       Size of blocks to use for I/O (in bytes, followed
                         by KB, MB or GB)
  -D, --disk-sleep=TIME
                       Time to sleep between iterations, in msec (default 100)
  -f, --disk-path=PATH Path to a file/directory to use as a buffer (default
                         /tmp); specify multiple times for additional paths
```

## Starting Lookbusy with Docker Compose

Add the following lines to an existing or new `docker-compose.yml` ...

```
  lookbusy:
    image: ghcr.io/vicchi/lookbusy:1.4.0
    restart: unless-stopped
    command:
      - --cpu-mode=curve
      - --cpu-util=10-15
```

## Packages

[GitHub Container Repository](https://github.com/vicchi/docker-lookbusy/pkgs/container/lookbusy)

## Licenses

Lookbusy is licensed under the [GPL](https://opensource.org/licenses/GPL-1.0); this repository is licensed as [BSD-3-Clause](./LICENSE).
