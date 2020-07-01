#include <iostream>
#include <cerrno>
#include <cstring>
#include <memory>
#include <string>
#include <cstdlib>

#include <sys/types.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

using namespace std;

constexpr size_t BUF_SIZE = 4096;

int read_file(string fname)
{
    auto fd = open(fname.c_str(), O_RDONLY);
    if (fd == -1) {
        cout << "open " << fname << ": " << strerror(errno) << "\n";
        return 1;
    }

    unique_ptr<char[]> buf {new(nothrow) char[BUF_SIZE]};
    if (!buf) {
        cout << "failed to allocate read buffer\n";
        return 1;
    }

    ssize_t r;
    do {
        r = read(fd, buf.get(), BUF_SIZE);
        if (r == -1) {
            cout << "read " << fname << ": " << strerror(errno) << "\n";
            return 1;
        }
        cout.write(buf.get(), r);
    } while (r > 0);

    r = close(fd);
    if (r == -1) {
        cout << "close " << fname << ": " << strerror(errno) << "\n";
        return 1;
    }

    return 0;
}

int read_dir(string dname)
{
    auto *dir = opendir(dname.c_str());
    if (dir == NULL) {
        cout << "opendir " << dname << ": " << strerror(errno) << "\n";
        return 1;
    }

	size_t initial = offsetof(struct dirent, d_name);
	cout << "offsetof(struct dirent, d_name): " << initial << "\n";

    while (1) {
		errno = 0;
		struct dirent *e = readdir(dir);
		if (e == NULL) {
			if (errno == 0)
				break;
            cout << "readdir " << dname << ": " << strerror(errno) << "\n";
			return 1;
		}
		string symtype;
		switch (e->d_type) {
        case DT_BLK:
            symtype = "BLK";
            break;
        case DT_CHR:
            symtype = "CHR";
            break;
        case DT_DIR:
            symtype = "DIR";
            break;
        case DT_FIFO:
            symtype = "FIFO";
            break;
        case DT_LNK:
            symtype = "LN";
            break;
        case DT_REG:
            symtype = "REG";
            break;
        case DT_SOCK:
            symtype = "SOCK";
            break;
        case DT_UNKNOWN:
            symtype = "UNKNOWN";
            break;
        default:
            cout << "wrong dirent type: " << e->d_type << "\n";
            return 1;
		}

		cout << "------------------------------\n";
		cout << "inode: " << e->d_ino << "\n";
		cout << "off: " << e->d_off << "\n";
		cout << "reclen: " << e->d_reclen
            << " (after initial: " << (e->d_reclen - initial) << ")\n";
		cout << "type: " << symtype << " (" << static_cast<int>(e->d_type) << ")\n";
		cout << "name: " << e->d_name << "\n";
	}

    return 0;
}

int read_common(string name)
{
    struct stat sb;
    if (stat(name.c_str(), &sb) == -1) {
        cout << "stat " << name << ": " << strerror(errno) << "\n";
        return 1;
    }

    switch (sb.st_mode & S_IFMT) {
    case S_IFREG:
        return read_file(name);
    case S_IFDIR:
        return read_dir(name);
    default:
        cout << "cannot handle file of type " << (sb.st_mode & S_IFMT);
        return 1;
    }
}

int main(int argc, char* argv[])
{
    // TODO OPT: Integrate all tests in one executable: like busybox (i.e.
    // switch on argv[0] for the test name and just do the rest in the module).
    // Maybe even add Makefile targets for altering the module configuration.
    if (argc >= 2) {
        read_common(argv[1]);
        return 0;
    }

    while (true) {
        cout << "virtiofs-test # ";
        string fname;
        getline(cin, fname);
        if (fname.empty() || fname.front() != '/') {
            return 0;
        }
        read_common(fname);
    }
}
