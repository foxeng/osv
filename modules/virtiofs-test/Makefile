CPPFLAGS = -std=c++11 -Wall -Wextra -pthread

.PHONY: module
module: simple

file-gen: file-gen.cc
	g++ -o file-gen $(CPPFLAGS) $(LDFLAGS) file-gen.cc

simple: simple.cc
	g++ -o virtiofs-test $(CPPFLAGS) $(LDFLAGS) simple.cc

concurrent: concurrent.cc
	g++ -o virtiofs-test $(CPPFLAGS) $(LDFLAGS) concurrent.cc

clean:
	rm -f virtiofs-test
