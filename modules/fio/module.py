import os

from osv.modules import api
from osv.modules.filemap import FileMap

# NOTE: These should be passed as arguments to scripts/build (see its
# documentation for module_makefile_arg, which is not limited to module
# makefiles).
fs = os.getenv('testfs', '')
if fs not in ('zfs', 'rofs', 'ramfs', 'virtiofs', 'nfs'):
    raise ValueError('test filesystem "{}" not supported'.format(fs))
testcase = tuple(os.getenv('testcase', '').split('-'))
if len(testcase) != 2 \
    or testcase[0] not in ('verify', 'single', 'many') \
    or testcase[1] not in ('serial', 'random'):

    raise ValueError('testcase "{}" not supported'.format('-'.join(testcase)))

# NOTE: fio fails with NFSv4: on the first read we get "fio: io_u error on file
# /nfs/modules/fio/data/single.0.0: Result not representable: read offset=0,
# buflen=4096". Initial troubleshooting indicates the problem lies with libnfs,
# since adding a print statement in lilbnfs/lib/libnfs-sync.c::202 (the end of
# wait_for_nfs_reply) makes it work, so it seems like a race (although pread
# returning ERANGE consistently is baffling).
nfs_version = '3'   # 3, 4
nfs_readahead = 1 << 21 # 2 MiB, same as virtiofs DAX readahead

mount_points = {
    'zfs': r'/',
    'rofs': r'/',
    'ramfs': r'/',
    'virtiofs': r'/virtiofs',
    'nfs': r'/nfs',
}

fio_params = {
    'zfs': {
        'directory': r'/data',
        'aux_path': r'/data',
    },
    'rofs': {
        'directory': r'/data',
        'aux_path': r'/data',
    },
    'ramfs': {
        'directory': r'/data',
        'aux_path': r'/data',
    },
    'virtiofs': {
        'directory': mount_points['virtiofs'],
        'aux_path': mount_points['virtiofs'],
    },
    'nfs': {
        'directory': mount_points['nfs'],
        'aux_path': mount_points['nfs'],
    }
}
if testcase[0] == 'many':
    for k in fio_params:
        fio_params[k]['directory'] += r'/many'

creates = {
    ('verify', 'serial'): r'/tests/verify-write.fio',
    ('verify', 'random'): r'/tests/verify-write.fio',
    ('single', 'serial'): r'/tests/single-create.fio',
    ('single', 'random'): r'/tests/single-create.fio',
    ('many', 'serial'): r'/tests/many-create.fio',
    ('many', 'random'): r'/tests/many-create.fio',
}

tests = {
    # NOTE: For verification we don't measure performance, so the jobs are all in one file
    ('verify', 'serial'): r'/tests/verify-read.fio',
    ('verify', 'random'): r'/tests/verify-read.fio',
    ('single', 'serial'): r'/tests/single-read-serial.fio',
    ('single', 'random'): r'/tests/single-read-random.fio',
    ('many', 'serial'): r'/tests/many-read-serial.fio',
    ('many', 'random'): r'/tests/many-read-random.fio',
}


# Add files
# NOTE: For ramfs, adding big files to the image fails (linker errors about relocations), so we
# don't add the files in advance, but create them at runtime.
usr_files = FileMap()
if fs in ('zfs', 'rofs'):
    if testcase[0] == 'verify':
        usr_files.add('${OSV_BASE}/modules/fio/data') \
            .to(fio_params[fs]['directory']) \
            .include('verify.0.0') \
            .include('verify.1.0')
        usr_files.add('${OSV_BASE}/modules/fio/data') \
            .to(fio_params[fs]['aux_path']) \
            .include('local-create-0-verify.state') \
            .include('local-create-1-verify.state')
    elif testcase[0] == 'single':
        usr_files.add('${OSV_BASE}/modules/fio/data') \
            .to(fio_params[fs]['directory']) \
            .include('single.0.0')
    else:
        usr_files.add('${OSV_BASE}/modules/fio/data') \
            .to(os.path.dirname(fio_params[fs]['directory'])) \
            .include('many/**')


# Run configuration for mounting NFS
export_point = r'/' if nfs_version == '4' else r'/home/fotis/workspace/ram/guest'
url_args = r'&'.join([
    r'readahead=' + str(nfs_readahead),
    r'autoreconnect=-1',
    r'version=' + nfs_version,
])
mount_args = [
    r'/tools/mount-fs.so',
    r'nfs',
    # NOTE: The command parser (core/commands.cc) accepts quoted strings only with double quotes
    r'"nfs://192.168.122.1' + export_point + r'?' + url_args + r'"',
    mount_points['nfs'],
]
mount_run = api.run_on_init(r' '.join(mount_args))

# For fio
api.require('libz')

# Run configuration for creating the files for fio
fio_create_args = [
    r'/usr/fio',
    r'--directory',
    fio_params[fs]['directory'],
    r'--aux-path',
    fio_params[fs]['aux_path'],
    creates[testcase],
]
fio_create_run = api.run_on_init(r' '.join(fio_create_args))

# Run configuration for the fio job
fio_args = [
    r'/usr/fio',
    r'--readonly',
    r'--minimal',
    r'--opendir' if testcase[0] == 'many' else r'--directory',
    fio_params[fs]['directory'],
    r'--aux-path',
    fio_params[fs]['aux_path'],
    tests[testcase],
]
fio_run = api.run(r' '.join(fio_args))

if fs == 'nfs':
    api.require('nfs')

default = (
    [mount_run] if fs == 'nfs'
    else [fio_create_run] if fs == 'ramfs'
    else []
) + [fio_run]
