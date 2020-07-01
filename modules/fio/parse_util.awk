BEGINFILE {
    util_name = ""
    delete virtiofsd_util
    virtiofsd_i = 0
    delete qemu_util
    qemu_i = 0
    delete vhost_util
    vhost_i = 0
    delete nfs_util
    nfs_i = 0
    delete virtiofsd_rss
    virtiofsd_rss_i = 0
    delete qemu_rss
    qemu_rss_i = 0
    delete virtiofsd_uss
    virtiofsd_uss_i = 0
    delete qemu_uss
    qemu_uss_i = 0
}

/^perf stat/ {
    # Lines of the form "perf stat {name}:", injected by run.py
    util_name = substr($3, 1, length($3) - 1)
}
/^[[:blank:]]*Performance counter stats for/ {
    cmd = $5
    # The order below is important: virtiofsd command line may include "qemu"
    if (cmd ~ "virtiofsd")
        util_name = "virtiofsd"
    else if (cmd ~ "qemu")
        util_name = "qemu"
    # All other cases should be preceded by a line caught by the previous rule
}
# Parse CPU utilization
NF > 1 && $NF == "utilized" && $(NF-1) == "CPUs"  {
    u = $(NF-2)
    if (util_name == "qemu")
        qemu_util[qemu_i++] = u
    else if (util_name == "vhost")
        vhost_util[vhost_i++] = u
    else if (util_name == "virtiofsd")
        virtiofsd_util[virtiofsd_i++] = u
    else {
        if (util_name != "nfs")
            printf "%s: WARNING: Treating CPU utilization with util name \"%s\" as nfs", FILENAME, \
                util_name > "/dev/stderr"
        nfs_util[nfs_i++] = u
    }
}

# Parse memory usage
/^Memory usage stats for/ {
    name = substr($5, 1, length($5) - 1)
    rss = $6
    uss = $7
    if (name == "virtiofsd") {
        virtiofsd_rss[virtiofsd_rss_i++] = rss
        virtiofsd_uss[virtiofsd_uss_i++] = uss
    } else if (name == "qemu") {
        qemu_rss[qemu_rss_i++] = rss
        qemu_uss[qemu_uss_i++] = uss
    } else
        printf "%s: WARNING: Ignoring memory usage with name \"%s\"", FILENAME, name > "/dev/stderr"
}
