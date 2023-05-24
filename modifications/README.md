# Modifications and Documentation

## Cache

The [`./cache`](./cache) folder provides an implementation for a write-through
write-allocate set-associative cache with several properties parameterized. This
cache sits between the PULPINO core and the data memory.

To add the cache to your design, you need to make two adjustments.

First, you need to adjust your core_region file to properly proxy the signals
between the Load-Store Unit and the Memory.

```bash
PULPINO=path/to/pulpino
REPO=path/to/this/repo
patch $PULPINO/rtl/core_region < $REPO/modifications/cache/core_region.sv.diff
```

Second, you need to add the `modifications/cache/set_associative.sv`,
`modifications/cache/cache_mem_wrap.sv`, `lfsr.sv`, and
`modifications/cache/replacement_policy.sv` to the source files of
the Vivado project's design sources.

> **NOTE**: This cache is not perfectly tested and may still show problems. A
> known problem is the lack of support for unaligned addresses. Furthermore, the
> cache also does not improve access times. In fact, the cache will always
> increase access time in comparison to the base implementation. This cache is
> to test security properties of the core and is made to generate an asymmetry
> between cached and non-cached accessed time. The cache is not made to resemble
> an efficient cache. 

The cache is parameterized, meaning you can adjust several parameters, including
the number of sets, number of ways, the 32-bit words per way and the replacement
policy. There are currently 4 replacement policies available: FIFO, Random, LRU
and MRU. All except the policy, can be set at the module instantiation. The
policy can be set at the module instantiation of `replacement_policy` within the
`set_associatve.sv` file.
