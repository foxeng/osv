#!/bin/gawk -f

@include "parse_common.awk"
@include "parse_boot.awk"
@include "parse_fio.awk"
@include "parse_util.awk"
@include "parse_vegeta.awk"


BEGIN {
    # NOTE: Specify output with the -v flag (e.g. -v output=csv)
    if (output != "csv" && output != "report")
        printf "WARNING: Output format specified is \"%s\", defaulting to report\n", output \
            > "/dev/stderr"

    # Print header with field names
    if (output == "csv")
        printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n", \
            "filename", \
            "boot_mean", \
            "boot_stdev", \
            "throughput_mean", \
            "throughput_stdev", \
            "rootfs", \
            "mount_mean", \
            "mount_stdev", \
            "app_start_mean", \
            "app_start_stdev", \
            "qemu_cpu_mean", \
            "qemu_cpu_stdev", \
            "vhost_cpu_mean", \
            "vhost_cpu_stdev", \
            "virtiofsd_cpu_mean", \
            "virtiofsd_cpu_stdev", \
            "nfs_cpu_mean", \
            "nfs_cpu_stdev", \
            "qemu_uss_mean", \
            "qemu_uss_stdev", \
            "virtiofsd_uss_mean", \
            "virtiofsd_uss_stdev", \
            "rps_mean", \
            "rps_stdev"
}


/^run.py: WARNING:/ { printf "%s: WARNING: \"%s\"\n", FILENAME, $0 > "/dev/stderr" }


ENDFILE {
    # TODO OPT: Only print this when some samples differ (i.e. !=others && !=0)
    printf "%s: INFO: Samples: %d %d %d %d %d %d %d %d %d %d %d\n", \
        FILENAME, \
        length(boot), \
        length(mount), \
        length(throughput), \
        length(app_start), \
        length(qemu_util), \
        length(vhost_util), \
        length(virtiofsd_util), \
        length(nfs_util), \
        length(qemu_uss), \
        length(virtiofsd_uss), \
        length(rps) \
        > "/dev/stderr"

    if (output == "csv") {
        # Fields:
        #  1. filename
        #  2. mean OSv boot time (ms)
        #  3. OSv boot time standard deviation (ms)
        #  4. (optional) mean fio throughput (KiB/s)
        #  5. (optional) fio throughput standard deviation (KiB/s)
        #  6. (optional) root filesystem type
        #  7. (optional) mean root filesystem mount time (ms)
        #  8. (optional) root filesystem mount time standard deviation (ms)
        #  9. (optional) mean app startup time (s)
        # 10. (optional) app startup time standard deviation (s)
        # 11. (optional) mean qemu CPU utilization
        # 12. (optional) qemu CPU utilization standard deviation
        # 13. (optional) mean vhost CPU utilization
        # 14. (optional) vhost CPU utilization standard deviation
        # 15. (optional) mean virtiofsd CPU utilization
        # 16. (optional) virtiofsd CPU utilization standard deviation
        # 17. (optional) mean nfs CPU utilization
        # 18. (optional) nfs CPU utilization standard deviation
        # 19. (optional) mean qemu memory (uss) usage (KiB)
        # 20. (optional) qemu memory (uss) usage standard deviation (KiB)
        # 21. (optional) mean virtiofsd memory usage (uss) (KiB)
        # 22. (optional) virtiofsd memory usage (uss) standard deviation (KiB)
        # 23. (optional) mean vegeta rps
        # 24. (optional) vegeta rps standard deviation

        printf "%s,%f,%f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
            basename(FILENAME),
            mean(boot),
            stdev(boot),
            ((length(throughput) > 0) ? sprintf("%f", mean(throughput)) : ""),
            ((length(throughput) > 0) ? sprintf("%f", stdev(throughput)) : ""),
            rootfs,
            ((rootfs != "") ? sprintf("%f", mean(mount)) : ""),
            ((rootfs != "") ? sprintf("%f", stdev(mount)) : ""),
            ((length(app_start) > 0) ? sprintf("%f", mean(app_start)) : ""),
            ((length(app_start) > 0) ? sprintf("%f", stdev(app_start)) : ""),
            ((length(qemu_util) > 0) ? sprintf("%f", mean(qemu_util)) : ""),
            ((length(qemu_util) > 0) ? sprintf("%f", stdev(qemu_util)) : ""),
            ((length(vhost_util) > 0) ? sprintf("%f", mean(vhost_util)) : ""),
            ((length(vhost_util) > 0) ? sprintf("%f", stdev(vhost_util)) : ""),
            ((length(virtiofsd_util) > 0) ? sprintf("%f", mean(virtiofsd_util)) : ""),
            ((length(virtiofsd_util) > 0) ? sprintf("%f", stdev(virtiofsd_util)) : ""),
            ((length(nfs_util) > 0) ? sprintf("%f", mean(nfs_util)) : ""),
            ((length(nfs_util) > 0) ? sprintf("%f", stdev(nfs_util)) : ""),
            ((length(qemu_uss) > 0) ? sprintf("%f", mean(qemu_uss) / 1024) : ""),
            ((length(qemu_uss) > 0) ? sprintf("%f", stdev(qemu_uss) / 1024) : ""),
            ((length(virtiofsd_uss) > 0) ? sprintf("%f", mean(virtiofsd_uss) / 1024) : ""),
            ((length(virtiofsd_uss) > 0) ? sprintf("%f", stdev(virtiofsd_uss) / 1024) : ""),
            ((length(rps) > 0) ? sprintf("%f", mean(rps)) : ""),
            ((length(rps) > 0) ? sprintf("%f", stdev(rps)) : "")
    } else {
        printf "%50s: %6.2f (%6.2f) ms boot\n", basename(FILENAME), mean(boot), stdev(boot)

        if (length(throughput) > 0)
            printf "%50s  %6.1f (%6.1f) MiB/s fio\n", "", mean(throughput) / 1024,
                stdev(throughput) / 1024

        if (rootfs != "")
            printf "%50s  %6.2f (%6.2f) %s ms mount\n", "", mean(mount), stdev(mount), rootfs
        if (length(app_start) > 0)
            printf "%50s  %6.3f (%6.3f) s startup\n", "", mean(app_start), stdev(app_start)

        # NOTE: CPU utilization = task-clock / walltime (and GHz = cycles / task-clock)
        if (length(qemu_util) > 0)
            printf "%50s  %6.3f (%6.3f) CPU qemu\n", "", mean(qemu_util), stdev(qemu_util)
        if (length(vhost_util) > 0)
            printf "%50s  %6.3f (%6.3f) CPU vhost\n", "", mean(vhost_util), stdev(vhost_util)
        if (length(virtiofsd_util) > 0)
            printf "%50s  %6.3f (%6.3f) CPU virtiofsd\n", "", mean(virtiofsd_util),\
                stdev(virtiofsd_util)
        if (length(nfs_util) > 0)
            printf "%50s  %6.3f (%6.3f) CPU nfs\n", "", mean(nfs_util), stdev(nfs_util)
        if (length(qemu_uss) > 0)
            printf "%50s  %6.1f (%6.1f) MiB qemu uss\n", "", (mean(qemu_uss) / 1024) / 1024,
                (stdev(qemu_uss) / 1024) / 1024
        if (length(virtiofsd_uss) > 0)
            printf "%50s  %6.1f (%6.1f) MiB virtiofsd uss\n", "", (mean(virtiofsd_uss) / 1024) / 1024,
                (stdev(virtiofsd_uss) / 1024) / 1024

        if (length(rps) > 0)
            printf "%50s  %6.2f (%6.2f) rps\n", "", mean(rps), stdev(rps)

        printf "\n"
    }
}
