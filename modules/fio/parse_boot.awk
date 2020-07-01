BEGINFILE {
    delete boot
    boot_i = 0
    rootfs = ""
    delete mount
    mount_i = 0
    delete app_start
    app_start_i = 0
}


# Parse OSv boot time
# ...when running without --bootchart
/^Booted up in/ { boot[boot_i++] = $4; }
# ...when running with --bootchart
/^[[:blank:]]*Total time:/ { boot[boot_i++] = strtonum(substr($3, 1, length($3) - 3)) }

# Parse root fs mount time
$2 == "mounted:" {
    tmp = tolower($1)
    if (rootfs != "" && rootfs != tmp)
        printf "%s: WARNING: Found root fs \"%s\" different from \"%s\", overriding", FILENAME, \
            tmp, rootfs  > "/dev/stderr"
    rootfs = tmp
    mount[mount_i++] = strtonum(substr($4, 3, length($4) - 5))
}

# Parse spring boot app start time
/Started SpringBoot2RestServiceApplication in/ {
    app_start[app_start_i++] = strtonum(substr($19, 1, length($19) - 1))
}
