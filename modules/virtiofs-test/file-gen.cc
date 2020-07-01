#include <iostream>
#include <array>

// TODO: Get from arguments
constexpr size_t BLOCK_SIZE = 4096;
// constexpr size_t BLOCKS = 1 << 8;
constexpr size_t BLOCKS = 4;

using namespace std;

int main(int argc, char *argv[])
{
    // TODO: Write directly to file, read filename from arguments
    array<char, BLOCK_SIZE> buf;
    for (int i = 0; i < BLOCKS; i++) {
        buf.fill(i % (1 << 8));
        cout.write(buf.data(), buf.size());
    }
}
