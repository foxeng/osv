BEGINFILE {
    delete rps
    rps_i = 0
}


# Parse vegeta rps
NF == 7 && $1 == "Requests"  { rps[rps_i++] = strtonum(substr($6, 1, length($6) - 1)) }

# Warn about failed requests
NF == 3 && $1 == "Success" {
    tmp = strtonum(substr($3, 1, length($3) - 1))
    if (tmp < 100)
        printf "%s: WARNING: Success ratio only %s\n", FILENAME, $3 > "/dev/stderr"
}
