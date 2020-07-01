#include <iostream>
#include <sstream>
#include <thread>
#include <mutex>
#include <array>
#include <vector>
#include <algorithm>
#include <cstring>
#include <chrono>
#include <functional>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

using namespace std;

// The size of each block in the test file. Each block contains BLOCK_SIZE bytes
// each with a value of <block_index> % 256.
constexpr size_t BLOCK_SIZE = 4096;

constexpr size_t NTHREADS = 4;

// Testcases:
// 1. Same / different fd.
// 2. Independent / overlapping file segments.

struct block {
    char id;
    int fd;
};

static mutex read_lock;

template<typename T>
void _atomic_print(ostringstream& oss, T head)
{
    oss << head;
    cout << oss.str();
}

template<typename T, typename... Args>
void _atomic_print(ostringstream& oss, T head, Args... tail)
{
    oss << head;
    _atomic_print(oss, tail...);
}

template<typename T, typename... Args>
void atomic_print(T head, Args... tail)
{
    ostringstream oss;
    oss << "[" << this_thread::get_id() << "] ";
    _atomic_print(oss, head, tail...);
}

bool read_and_verify(const block& b)
{
    array<char, BLOCK_SIZE> buf;

    ssize_t r;
    for (size_t r_tot = 0; r_tot < buf.size(); r_tot += r) {
        // lock_guard<mutex> lock {read_lock};
        r = read(b.fd, buf.data() + r_tot, buf.size() - r_tot);
        if (r == -1) {
            atomic_print("read: ", strerror(errno), "\n");
            return false;
        }
        auto thash = hash<thread::id> {}(this_thread::get_id());
        chrono::microseconds jitter {thash % 10000};
        this_thread::sleep_for(jitter);
    }

    return all_of(buf.cbegin(), buf.cend(), [&b](char c) { return c == b.id; });
}

bool read_and_verify(string fname)
{
    auto fd = open(fname.c_str(), O_RDONLY);
    if (fd == -1) {
        atomic_print("open ", fname, ": ", strerror(errno), "\n");
        return false;
    }

    // Get number of blocks
    struct stat st;
    if (fstat(fd, &st) == -1) {
        atomic_print("fstat: ", fname, ": ", strerror(errno), "\n");
    }
    auto fsize = st.st_size;
    auto nblocks = min<size_t>(fsize / BLOCK_SIZE, (1 << 8) - 1);

    bool ret = false;
    block b;
    b.fd = fd;
    for (b.id = 0; b.id < nblocks; b.id++) {
        if (!read_and_verify(b)) {
            atomic_print("block ", b.id, " FAILED\n");
            goto out_w_file;
        }
    }
    atomic_print("test ", fname, ": SUCCESS!\n");

out_w_file:
    auto r = close(fd);
    if (r == -1) {
        atomic_print("close ", fname, ": ", strerror(errno), "\n");
        return false;
    }

    return ret;
}

void run_test(size_t nthreads, const string& fname)
{
    vector<thread> threads;
    for (int i = 0; i < nthreads; i++) {
        threads.emplace_back(
            [](string fname) { read_and_verify(fname); }, fname);
    }

    for (auto& t : threads) {
        t.join();
    }
}

void run_test(const vector<string>& fnames)
{
    vector<thread> threads;
    for (auto& fname : fnames) {
        threads.emplace_back(
            [](string fname) { read_and_verify(fname); }, fname);
    }

    for (auto& t : threads) {
        t.join();
    }
}

int main(int argc, char* argv[])
{
    if (argc >= 2) {
        if (argc < 3) {
            run_test(NTHREADS, argv[1]);
        } else {
            vector<string> fnames;
            for (int i = 1; i < argc; i++) {
                fnames.emplace_back(argv[i]);
            }
            run_test(fnames);
        }
        return 0;
    }

    while (true) {
        // Get next line of input
        cout << "virtiofs-test # ";
        string input;
        getline(cin, input);
        if (input.empty() || input.find("exit") == 0) {
            return 0;
        }

        // Split into filenames
        stringstream ss {input};
        vector<string> fnames;
        for (string s; ss >> s;) {
            fnames.push_back(s);
        }

        // Run test
        if (fnames.size() == 1) {
            run_test(NTHREADS, fnames.front());
        } else {
            run_test(fnames);
        }
    }
}
