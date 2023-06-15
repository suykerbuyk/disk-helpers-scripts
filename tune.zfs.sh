# Description of tuneables:
#   https://openzfs.github.io/openzfs-docs/man/4/zfs.4.html

# Practical upper limit of total metaslabs per top-level vdev.
# This parameter will only have an effect if it is changed before the pool is created.
# After the pool has been created, this value will not have any effect.
# This sets the maximum number of metaslabs allowed per vdev. By adjusting this parameter, you can control
# the number of metaslabs within a vdev, Reducing the vdev_ms_count_limit value can lead to fewer
# metaslabs within a vdev resulting in reduced memory usage for metaslab-related metadata, potentially
# making the system more responsive. However, having fewer metslabs can also lead to less granular space
# managemement and increased fragmentation, which may negatively impact performance over time.
# More metaslabs can improve space allocation granularity and reduce fragmentation, potentially leading
# to better better performance in certain workloads, especially those with random writes.
# However, having more metaslabs can also increase teh memory footprint for metaslab related meta-data. 
# This parameter must be changed BEFORE the pool is created.
echo 8192 >/sys/module/zfs/parameters/zfs_vdev_ms_count_limit

# Max vdev I/O aggregation size.
# The zfs_vdev_aggregation_limit parameter controls the max vdev I/O aggregation size.
# When multiple I/O request are issued to a vdev, ZFS can aggregate these requests to reduce the
# number of I/O operations, which in turn reduces the load on the storage devices and improves
# performance.  However, there can be negative ramifications from setting this value too high,
# as it can increase latency due to the time required to process the larger aggregated I/O.
# To reduce IOPS, small, adjacent I/Os can be aggregated into a large I/O/ For reads, aggregations
# can occur across small adjacency gaps of as much as zfs_vdev_read_gap_limit.  This will result
# in an "over read", but usually results in a performance increase.  Fro writes, aggregation can
# occur at the ZFS or disk level, similarly, governed by zfs_vdev_write_gap_limit.
# zfs_vdev_aggegation_limit is the upper bound on the size of the larger, aggregated I/O.
echo 16777216 >/sys/module/zfs/parameters/zfs_vdev_aggregation_limit

# The benefits of larger blocks, and thus larger I/O, need to be weighed against the cost of COWing
# a giant block to modify one byte. Additionally, very large blocks can have an impact on I/O latency,
# and also potentially on the memory allocator. 
# Record sizes of up to 16M are supported with the large_blocks pool feeature, which is enabled by
# default on new pools on systems that support it.  However, record sizes larger than 1M were disabled
# by default before OpenZFS 2.2 unless the zfs_max_recordsize kernel module parameter is set to allow
# sizes greater than 1M.
echo 16777216 >/sys/module/zfs/parameters/zfs_max_recordsize

# Default upper limit for metaslab size.
# The zfs_vdev_max_ms_shift parameter sets the upper limit for each metaslab's size. The default value
# is 34 which coorelates to 16GiB(2^34).
echo 40 >/sys/module/zfs/parameters/zfs_vdev_max_ms_shift

# Default queue depth for each vdev IO allocator. Higher values allow for better coalescing of sequential
# writes before sending them to the disk, but can increase transaction commit times.
# The zfs_vdev_def_queue_depth parameter sets the queue depth per allocator for aggregation of
# sequential writes to a vdev.  Raising the value allows more items to be queued, and to then be
# aggregated together into fewer large operations, improving performance.  The default is 32, however
# a value of 256 gives better performance on Corvault.
# This requires Klara commit ece7ab7e7de81a9a51923d7baa7db3577de4aace
echo 256 >/sys/module/zfs/parameters/zfs_vdev_def_queue_depth

# Maximum asynchronous read I/O operations active to each device
# The zfs_vdev_async_read_max_active parameter is the maximum asynchronous read I/O
# operations active to each vdev. Asynchronous reads are generated with ZFS by features such a the
# prefetcher, and reads triggered by a user or application will usually be synchronous. The default is 3,
# however, a value of 32 provides much better performance for Corvault. The disadvantage to increasing
# the value is that it can result in higher latency, but since Corvault has many spindles in each vdev,
# the chances of this are less likely.
echo 32 >/sys/module/zfs/parameters/zfs_vdev_async_read_max_active

# Maximum synchronous read I/O operations active to each device
# Default=10
echo 64 >/sys/module/zfs/parameters/zfs_vdev_sync_read_max_active

# Maximum asynchronous write I/O operations active to each device.
# Default 10
echo 64 >/sys/module/zfs/parameters/zfs_vdev_async_write_max_active

# Maximum synchronous write I/O operations active to each device.
# Default 10
echo 64 >/sys/module/zfs/parameters/zfs_vdev_sync_write_max_active

# Controls the amount of time that a log (ZIL) write block (lwb) remains “open” when it isn’t “full”
# and it has a thread waiting to commit to stable storage. The timeout is scaled based on a percentage
# of the last lwb latency to avoid significantly impacting the latency of each individual intent log
# transaction (itx).
# This parameter controls the amount of time that a log (ZIL) write block (lwb) remains "open" when
# it isn't "full" and it has a thread waiting to commit to stable storage. The timeout is scaled based
# a percentage of the last lwb latency to avoid significantly impacting the latency of each individual
# intent log transaction.  The default is five percent, however a value of 10 percent may result in
# slightly increased latency, but fewer FLUSH operations to the backing disks, yielding better overall
# throughput.
# Default 5
echo 64 >/sys/module/zfs/parameters/zfs_commit_timeout_pct

# Sets the metaslab granularity. Nominally, ZFS will try to allocate this amount of data to a top-level
# vdev before moving on to the next top-level vdev. This is roughly similar to what would be referred to
# as the “stripe size” in traditional RAID arrays.
# This parameter is an internal tunable that controls teh metaslab granualrity. In normal conditions,
# ZFS will try to allocate this amout of data to a top-level vdev before moving on to the next top-level
# vdev. When tuning for HDDs, it can be more efficient to have a few larger, sequential writes to teh device
# rather than switching to the next device. Monitoring the size of contigous writes to the disk relative to
# the write throughput can be used to dtermine if the increaseing metaslab_aliquot can help.
# default 512288
echo 16777216 >/sys/module/zfs/parameters/metaslab_aliquot

echo 51539607552 >/sys/module/zfs/parameters/zfs_dirty_data_max

#spl.conf
echo 8 >/sys/module/spl/parameters/spl_kmem_cache_kmem_threads
echo 64 >/sys/module/spl/parameters/spl_kmem_cache_obj_per_slab
echo 1024 >/sys/module/spl/parameters/spl_kmem_cache_max_size
