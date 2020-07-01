configure_flags = --disable-numa --disable-rdma --disable-rados --disable-rbd \
	--disable-http --disable-gfapi --disable-pmem --disable-shm \
	--disable-tcmalloc


.PHONY: module clean distclean

module: fio/fio data

fio:
	# TODO OPT: Fetch upstream, pin version, add osv-specific patches to tree
	# and apply them here
	git clone --depth 1 --single-branch -b osv https://github.com/foxeng/fio.git

fio/fio: fio
	cd fio && ./configure $(configure_flags) && make -j 8

data: fio/fio
	mkdir -p data
	./fio/fio --directory data tests/single-create.fio
	mkdir -p data/many
	./fio/fio --directory data/many tests/many-create.fio


clean:
	cd fio && make clean

distclean:
	rm -rf fio data
