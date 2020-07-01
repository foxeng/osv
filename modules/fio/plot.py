#!/usr/bin/env python3

import csv
import sys

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt

SHARED_FS = ('linux-virtiofs', 'linux-dax', 'nfs', 'virtiofs', 'dax')

SHARED_HATCH = 'O'

TPUT_COLOR = 'tab:blue'
RPS_COLOR = 'tab:blue'

QEMU_COLOR = 'tab:blue'
VIRTIOFSD_COLOR = 'tab:orange'
VHOST_COLOR = 'tab:green'
NFS_COLOR = 'tab:red'

OSV_COLOR = 'tab:blue'
MOUNT_COLOR = 'tab:orange'
APP_COLOR = 'tab:green'

def usage():
    print('Usage: {} <plot> [<testcase>]'.format(sys.argv[0]), file=sys.stderr)
    print('where:', file=sys.stderr)
    print('\tplot: one of fio, startup, nginx', file=sys.stderr)
    print('\ttestcase: when plot is fio, the fio testcase', file=sys.stderr)
    sys.exit(1)


def float_or_zero(d, s):
    try:
        return float(d[s])
    except ValueError:
        return 0


def index_non_zero(*args):
    """Return the indices of elements in *args where at least one is non-zero."""
    sums = [sum(x) for x in zip(*args)]
    return [i for i, v in enumerate(sums) if v > 0]


def f(l, indices):
    """Return l, where only elements with index in indices are preserved."""
    return [v for i, v in enumerate(l) if i in indices]


def g(l, ls=None):
    """Return ls, with each element extended by the respective element of l."""
    if ls is None:
        return [[x] for x in l]
    return [xs + [x] for xs, x in zip(ls, l)]


def add_hatches(bars, labels):
    """Add hatches to the bars with labels corresponding to shared filesystems."""
    for bar, fs in zip(bars, labels):
        # TODO OPT: Add hatches to non-shared fs too?
        if fs in SHARED_FS:
            for bar_stack in bar:
                bar_stack.set_hatch(SHARED_HATCH)


if len(sys.argv) < 2 or sys.argv[1] not in ('fio', 'startup', 'nginx'):
    usage()
plot = sys.argv[1]
if plot not in ('fio', 'startup', 'nginx'):
    usage()
if plot == 'fio':
    if len(sys.argv) < 3:
        usage()
    fio_testcase = sys.argv[2]

# Parse results
# TODO OPT: Allow reading from file
reader = csv.DictReader(sys.stdin)
results = [row for row in reader]

# Custom-sort results
def cmp(r):
    return {
        'host': 1,
        'linux-virtiofs': 2,
        'linux-dax': 3,
        'nfs': 4,
        'virtiofs': 5,
        'dax': 6,
        'zfs': 7,
        'rofs': 8,
        'ramfs': 9,
    }[r['filename']]
results.sort(key=cmp)

# Make room for everything in the plots
plt.rcParams.update({'figure.autolayout': True})

# Plot
if plot == 'fio':
    labels = [r['filename'] for r in results]
    tput_means = [float(r['throughput_mean']) / 1024 for r in results]
    tput_stds = [float(r['throughput_stdev']) / 1024 for r in results]
    qemu_cpu_means = [float_or_zero(r, 'qemu_cpu_mean') for r in results]
    qemu_cpu_stds = [float_or_zero(r, 'qemu_cpu_stdev') for r in results]
    vhost_cpu_means = [float_or_zero(r, 'vhost_cpu_mean') for r in results]
    vhost_cpu_stds = [float_or_zero(r, 'vhost_cpu_stdev') for r in results]
    virtiofsd_cpu_means = [float_or_zero(r, 'virtiofsd_cpu_mean') for r in results]
    virtiofsd_cpu_stds = [float_or_zero(r, 'virtiofsd_cpu_stdev') for r in results]
    nfs_cpu_means = [float_or_zero(r, 'nfs_cpu_mean') for r in results]
    nfs_cpu_stds = [float_or_zero(r, 'nfs_cpu_stdev') for r in results]
    qemu_uss_means = [float_or_zero(r, 'qemu_uss_mean') for r in results]
    qemu_uss_stds = [float_or_zero(r, 'qemu_uss_stdev') for r in results]
    virtiofsd_uss_means = [float_or_zero(r, 'virtiofsd_uss_mean') for r in results]
    virtiofsd_uss_stds = [float_or_zero(r, 'virtiofsd_uss_stdev') for r in results]

    fig, ax = plt.subplots()
    # ax.set_title('fio ({})'.format(fio_testcase))
    ax.set_ylabel('Throughput (MiB/s)')
    iis = index_non_zero(tput_means)
    f_labels_tput = f(labels, iis)
    f_tput_means = f(tput_means, iis)
    f_tput_stds = f(tput_stds, iis)
    # NOTE: The "alpha=1" is a workaround. See
    # https://stackoverflow.com/questions/5195466/matplotlib-does-not-display-hatching-when-rendering-to-pdf
    bars = g(ax.bar(f_labels_tput, f_tput_means, yerr=f_tput_stds, color=TPUT_COLOR, alpha=1))
    add_hatches(bars, f_labels_tput)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    # NOTE: We make the legend manually, to get the colors / hatches right.
    ax.legend(handles=[
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('fio-{}-tput.pdf'.format(fio_testcase))

    fig, ax = plt.subplots()
    # ax.set_title('fio ({})'.format(fio_testcase))
    ax.set_ylabel('CPUs utilized')
    iis = index_non_zero(qemu_cpu_means, virtiofsd_cpu_means, vhost_cpu_means, nfs_cpu_means)
    f_labels_cpu = f(labels, iis)
    f_qemu_cpu_means = f(qemu_cpu_means, iis)
    f_qemu_cpu_stds = f(qemu_cpu_stds, iis)
    f_virtiofsd_cpu_means = f(virtiofsd_cpu_means, iis)
    f_virtiofsd_cpu_stds = f(virtiofsd_cpu_stds, iis)
    f_vhost_cpu_means = f(vhost_cpu_means, iis)
    f_vhost_cpu_stds = f(vhost_cpu_stds, iis)
    f_nfs_cpu_means = f(nfs_cpu_means, iis)
    f_nfs_cpu_stds = f(nfs_cpu_stds, iis)
    bars = g(ax.bar(f_labels_cpu, f_qemu_cpu_means, yerr=f_qemu_cpu_stds, label='QEMU',
        color=QEMU_COLOR, alpha=1))
    bars = g(ax.bar(f_labels_cpu, f_virtiofsd_cpu_means, yerr=f_virtiofsd_cpu_stds,
        label='virtiofsd', color=VIRTIOFSD_COLOR, bottom=f_qemu_cpu_means, alpha=1), bars)
    bars = g(ax.bar(f_labels_cpu, f_vhost_cpu_means, yerr=f_vhost_cpu_stds, label='vhost',
        color=VHOST_COLOR, bottom=[sum(x) for x in zip(f_qemu_cpu_means, f_virtiofsd_cpu_means)],
        alpha=1), bars)
    bars = g(ax.bar(f_labels_cpu, f_nfs_cpu_means, yerr=f_nfs_cpu_stds, label='NFS',
        color=NFS_COLOR,
        bottom=[sum(x) for x in zip(f_qemu_cpu_means, f_virtiofsd_cpu_means, f_vhost_cpu_means)],
        alpha=1), bars)
    add_hatches(bars, f_labels_cpu)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    ax.legend(handles=[
        mpatches.Patch(color=QEMU_COLOR, label='QEMU'),
        mpatches.Patch(color=VIRTIOFSD_COLOR, label='virtiofsd'),
        mpatches.Patch(color=VHOST_COLOR, label='vhost'),
        mpatches.Patch(color=NFS_COLOR, label='NFS'),
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('fio-{}-cpu.pdf'.format(fio_testcase))

    fig, ax = plt.subplots()
    # ax.set_title('fio ({})'.format(fio_testcase))
    ax.set_ylabel('Memory usage (MiB)')
    iis = index_non_zero(qemu_uss_means, virtiofsd_uss_means)
    f_labels_memu = f(labels, iis)
    f_qemu_uss_means = f(qemu_uss_means, iis)
    f_qemu_uss_stds = f(qemu_uss_stds, iis)
    f_virtiofsd_uss_means = f(virtiofsd_uss_means, iis)
    f_virtiofsd_uss_stds = f(virtiofsd_uss_stds, iis)
    bars = g(ax.bar(f_labels_memu, f_qemu_uss_means, yerr=f_qemu_uss_stds, label='QEMU',
        color=QEMU_COLOR, alpha=1))
    bars = g(ax.bar(f_labels_memu, f_virtiofsd_uss_means, yerr=f_virtiofsd_uss_stds,
        label='virtiofsd', color=VIRTIOFSD_COLOR, bottom=f_qemu_uss_means, alpha=1), bars)
    add_hatches(bars, f_labels_memu)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    ax.legend(handles=[
        mpatches.Patch(color=QEMU_COLOR, label='QEMU'),
        mpatches.Patch(color=VIRTIOFSD_COLOR, label='virtiofsd'),
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('fio-{}-memu.pdf'.format(fio_testcase))
elif plot == 'startup':
    labels = [r['filename'] for r in results]
    boot_means = [float(r['boot_mean']) for r in results]
    boot_stds = [float(r['boot_stdev']) for r in results]
    mount_means = [float(r['mount_mean']) for r in results]
    mount_stds = [float(r['mount_stdev']) for r in results]
    boot2_means = [b - m for b, m in zip(boot_means, mount_means)]  # boot time minus mount time
    boot2_stds = [b - m for b, m in zip(boot_stds, mount_stds)]
    app_start_means = [float(r['app_start_mean']) * 1000 for r in results]
    app_start_stds = [float(r['app_start_stdev']) * 1000 for r in results]

    fig, ax = plt.subplots()
    # ax.set_title('Spring boot example application')
    # TODO OPT: Or report in seconds?
    ax.set_ylabel('Startup time (ms)')
    iis = index_non_zero(boot_means, app_start_means)
    f_labels_boot = f(labels, iis)
    f_boot2_means = f(boot2_means, iis)
    f_boot2_stds = f(boot2_stds, iis)
    f_mount_means = f(mount_means, iis)
    f_mount_stds = f(mount_stds, iis)
    f_app_start_means = f(app_start_means, iis)
    f_app_start_stds = f(app_start_stds, iis)
    bars = g(ax.bar(f_labels_boot, f_boot2_means, yerr=f_boot2_stds, label='OSv boot',
        color=OSV_COLOR, alpha=1))
    bars = g(ax.bar(f_labels_boot, f_mount_means, yerr=f_mount_stds, label='Root fs mount',
        bottom=f_boot2_means, color=MOUNT_COLOR, alpha=1), bars)
    bars = g(ax.bar(f_labels_boot, f_app_start_means, yerr=f_app_start_stds, label='Application',
        color=APP_COLOR, bottom=[sum(x) for x in zip(f_boot2_means, f_mount_means)], alpha=1), bars)
    add_hatches(bars, f_labels_boot)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    ax.legend(handles=[
        mpatches.Patch(color=OSV_COLOR, label='OSv boot'),
        mpatches.Patch(color=MOUNT_COLOR, label='Root fs mount'),
        mpatches.Patch(color=APP_COLOR, label='Application'),
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('startup-app.pdf')

    # TODO OPT: Remove completely since it has been embedded to the above?
    fig, ax = plt.subplots()
    # ax.set_title('Spring boot example application')
    ax.set_ylabel('Mount time (ms)')
    iis = index_non_zero(mount_means)
    f_labels_mount = f(labels, iis)
    f_mount_means = f(mount_means, iis)
    f_mount_stds = f(mount_stds, iis)
    bars = g(ax.bar(labels, mount_means, yerr=mount_stds, color=MOUNT_COLOR, alpha=1))
    add_hatches(bars, f_labels_mount)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    ax.legend(handles=[
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('startup-mount.pdf')
elif plot == 'nginx':
    labels = [r['filename'] for r in results]
    rps_means = [float(r['rps_mean']) for r in results]
    rps_stds = [float(r['rps_stdev']) for r in results]
    qemu_cpu_means = [float_or_zero(r, 'qemu_cpu_mean') for r in results]
    qemu_cpu_stds = [float_or_zero(r, 'qemu_cpu_stdev') for r in results]
    vhost_cpu_means = [float_or_zero(r, 'vhost_cpu_mean') for r in results]
    vhost_cpu_stds = [float_or_zero(r, 'vhost_cpu_stdev') for r in results]
    virtiofsd_cpu_means = [float_or_zero(r, 'virtiofsd_cpu_mean') for r in results]
    virtiofsd_cpu_stds = [float_or_zero(r, 'virtiofsd_cpu_stdev') for r in results]
    nfs_cpu_means = [float_or_zero(r, 'nfs_cpu_mean') for r in results]
    nfs_cpu_stds = [float_or_zero(r, 'nfs_cpu_stdev') for r in results]
    qemu_uss_means = [float_or_zero(r, 'qemu_uss_mean') for r in results]
    qemu_uss_stds = [float_or_zero(r, 'qemu_uss_stdev') for r in results]
    virtiofsd_uss_means = [float_or_zero(r, 'virtiofsd_uss_mean') for r in results]
    virtiofsd_uss_stds = [float_or_zero(r, 'virtiofsd_uss_stdev') for r in results]

    fig, ax = plt.subplots()
    # ax.set_title('nginx HTTP load test')
    ax.set_ylabel('RPS')
    iis = index_non_zero(rps_means)
    f_labels_rps = f(labels, iis)
    f_rps_means = f(rps_means, iis)
    f_rps_stds = f(rps_stds, iis)
    bars = g(ax.bar(f_labels_rps, f_rps_means, yerr=f_rps_stds, color=RPS_COLOR, alpha=1))
    add_hatches(bars, f_labels_rps)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    ax.legend(handles=[
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('nginx-rps.pdf')

    fig, ax = plt.subplots()
    # ax.set_title('nginx HTTP load test')
    ax.set_ylabel('CPUs utilized')
    iis = index_non_zero(qemu_cpu_means, virtiofsd_cpu_means, vhost_cpu_means, nfs_cpu_means)
    f_labels_cpu = f(labels, iis)
    f_qemu_cpu_means = f(qemu_cpu_means, iis)
    f_qemu_cpu_stds = f(qemu_cpu_stds, iis)
    f_virtiofsd_cpu_means = f(virtiofsd_cpu_means, iis)
    f_virtiofsd_cpu_stds = f(virtiofsd_cpu_stds, iis)
    f_vhost_cpu_means = f(vhost_cpu_means, iis)
    f_vhost_cpu_stds = f(vhost_cpu_stds, iis)
    f_nfs_cpu_means = f(nfs_cpu_means, iis)
    f_nfs_cpu_stds = f(nfs_cpu_stds, iis)
    bars = g(ax.bar(f_labels_cpu, f_qemu_cpu_means, yerr=f_qemu_cpu_stds, label='QEMU',
        color=QEMU_COLOR, alpha=1))
    bars = g(ax.bar(f_labels_cpu, f_virtiofsd_cpu_means, yerr=f_virtiofsd_cpu_stds,
        label='virtiofsd', color=VIRTIOFSD_COLOR, bottom=f_qemu_cpu_means, alpha=1), bars)
    bars = g(ax.bar(f_labels_cpu, f_vhost_cpu_means, yerr=f_vhost_cpu_stds, label='vhost',
        bottom=[sum(x) for x in zip(f_qemu_cpu_means, f_virtiofsd_cpu_means)], color=VHOST_COLOR,
        alpha=1), bars)
    bars = g(ax.bar(f_labels_cpu, f_nfs_cpu_means, yerr=f_nfs_cpu_stds, label='NFS',
        bottom=[sum(x) for x in zip(f_qemu_cpu_means, f_virtiofsd_cpu_means, f_vhost_cpu_means)],
        color=NFS_COLOR, alpha=1), bars)
    add_hatches(bars, f_labels_cpu)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    ax.legend(handles=[
        mpatches.Patch(color=QEMU_COLOR, label='QEMU'),
        mpatches.Patch(color=VIRTIOFSD_COLOR, label='virtiofsd'),
        mpatches.Patch(color=VHOST_COLOR, label='vhost'),
        mpatches.Patch(color=NFS_COLOR, label='NFS'),
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('nginx-cpu.pdf')

    fig, ax = plt.subplots()
    # ax.set_title('nginx HTTP load test')
    ax.set_ylabel('Memory usage (MiB)')
    iis = index_non_zero(qemu_uss_means, virtiofsd_uss_means)
    f_labels_memu = f(labels, iis)
    f_qemu_uss_means = f(qemu_uss_means, iis)
    f_qemu_uss_stds = f(qemu_uss_stds, iis)
    f_virtiofsd_uss_means = f(virtiofsd_uss_means, iis)
    f_virtiofsd_uss_stds = f(virtiofsd_uss_stds, iis)
    bars = g(ax.bar(f_labels_memu, qemu_uss_means, yerr=qemu_uss_stds, label='QEMU',
        color=QEMU_COLOR, alpha=1))
    bars = g(ax.bar(f_labels_memu, virtiofsd_uss_means, yerr=virtiofsd_uss_stds, label='virtiofsd',
        bottom=qemu_uss_means, color=VIRTIOFSD_COLOR, alpha=1), bars)
    add_hatches(bars, f_labels_memu)
    plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
    ax.legend(handles=[
        mpatches.Patch(color=QEMU_COLOR, label='QEMU'),
        mpatches.Patch(color=VIRTIOFSD_COLOR, label='virtiofsd'),
        mpatches.Patch(hatch=SHARED_HATCH, color='none', alpha=1, label='Shared fs'),
    ])
    fig.savefig('nginx-memu.pdf')
