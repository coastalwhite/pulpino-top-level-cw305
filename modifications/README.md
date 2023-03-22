# Modifications and Documentation

## Cache

For the cache, you need to make two adjustments.

First, you need to adjust your core_region file to properly proxy the signals
between the Load-Store Unit and the Memory.

```bash
PULPINO=path/to/pulpino
REPO=path/to/this/repo
patch $PULPINO/rtl/core_region < $REPO/modifications/cache/core_region.sv.diff
```

Second, you need to add the `modifications/cache/cache_compat.sv` to the source
files of the Vivado project's design sources.
