function mean(a,    sum, cnt, i)
{
    for (i in a) {
        sum += a[i]
        cnt++
    }

    return (cnt > 0) ? (sum / cnt) : 0
}

function stdev(a,   m, sum, cnt, i)
{
    m = mean(a)
    for (i in a) {
        sum += (a[i] - m) ** 2
        cnt++
    }

    return (cnt > 0) ? sqrt(sum / cnt) : 0
}

function basename(file, a, n) {
    n = split(file, a, "/")
    return a[n]
}
