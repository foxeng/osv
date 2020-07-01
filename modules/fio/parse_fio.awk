BEGINFILE {
    delete throughput
    throughput_i = 0
}


# Parse fio throughput
/^3;fio-/  {
    split($0, fio_fields, ";")
    throughput[throughput_i++] = fio_fields[7]
}
