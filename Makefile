PROC_COUNT+="$(shell nproc)"
CMAKE_INSTALL_PREFIX=$(shell realpath .)
GO_LDFLAG_VERSION := -X 'main.Version=$(shell git describe --all --dirty)'

buildpath=$(realpath ./build)
$(shell mkdir -p ./bin)
$(shell mkdir -p ./build)

.PHONY: all
all: download mistserver livepeer-log

.PHONY: ffmpeg
ffmpeg:
	mkdir -p build
	cd ../go-livepeer && ./install_ffmpeg.sh $(buildpath)

.PHONY: build
build:
	go build -ldflags="$(GO_LDFLAG_VERSION)" -o build/downloader main.go

build/compiled/lib/libmbedtls.a:
	export PKG_CONFIG_PATH=$(buildpath)/compiled/lib/pkgconfig \
	&& export LD_LIBRARY_PATH=$(buildpath)/compiled/lib \
	&& export C_INCLUDE_PATH=$(buildpath)/compiled/include \
	&& git clone -b dtls_srtp_support --depth=1 https://github.com/livepeer/mbedtls.git $(buildpath)/mbedtls \
  && cd $(buildpath)/mbedtls \
  && mkdir build \
  && cd build \
  && cmake -DCMAKE_INSTALL_PREFIX=$(buildpath)/compiled .. \
  && make -j$(nproc) install

build/compiled/lib/libsrtp2.a:
	git clone https://github.com/cisco/libsrtp.git $(buildpath)/libsrtp \
  && cd $(buildpath)/libsrtp \
  && mkdir build \
  && cd build \
  && cmake -DCMAKE_INSTALL_PREFIX=$(buildpath)/compiled .. \
  && make -j$(nproc) install

build/compiled/lib/libsrt.a: build/compiled/lib/libmbedtls.a
build/compiled/lib/libsrt.a:
	git clone https://github.com/Haivision/srt.git $(buildpath)/srt \
  && cd $(buildpath)/srt \
  && mkdir build \
  && cd build \
  && cmake .. -DCMAKE_INSTALL_PREFIX=$(buildpath)/compiled -D USE_ENCLIB=mbedtls -D ENABLE_SHARED=false \
  && make -j$(nproc) install

mistserver: build/compiled/lib/libmbedtls.a build/compiled/lib/libsrtp2.a build/compiled/lib/libsrt.a

.PHONY: mistserver
mistserver:
	set -x \
	export PKG_CONFIG_PATH=$(buildpath)/compiled/lib/pkgconfig \
	export LD_LIBRARY_PATH=~$(buildpath)/compiled/lib \
	export C_INCLUDE_PATH=~$(buildpath)/compiled/include \
	&& mkdir -p ./build/mistserver \
	&& cd ./build/mistserver \
	&& cmake ../../../mistserver -DPERPETUAL=1 -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} -DCMAKE_PREFIX_PATH=$(buildpath)/compiled \
	&& make -j${PROC_COUNT} \
	&& make -j${PROC_COUNT} MistProcLivepeer \
	&& make install

.PHONY: go-livepeer
go-livepeer:
	set -x \
	&& cd ../go-livepeer \
	&& PKG_CONFIG_PATH=$(buildpath)/compiled/lib/pkgconfig make livepeer livepeer_cli \
	&& cd - \
	&& mv ../go-livepeer/livepeer ./bin/livepeer \
	&& mv ../go-livepeer/livepeer_cli ./bin/livepeer-cli

.PHONY: livepeer-task-runner
livepeer-task-runner:
	set -x \
	&& cd ../task-runner \
	&& PKG_CONFIG_PATH=$(buildpath)/compiled/lib/pkgconfig make \
	&& cd - \
	&& mv ../task-runner/build/task-runner ./bin/livepeer-task-runner

.PHONY: livepeer-www
livepeer-www:
	set -x \
	&& cd ../livepeer-com/packages/www \
	&& yarn run pkg:local \
	&& cd - \
	&& mv ../livepeer-com/packages/www/bin/www ./bin/livepeer-www

.PHONY: livepeer-api
livepeer-api:
	set -x \
	&& cd ../livepeer-com/packages/api \
	&& yarn run pkg:local \
	&& cd - \
	&& mv ../livepeer-com/packages/api/bin/api ./bin/livepeer-api

.PHONY: livepeer-mist-api-connector
livepeer-mist-api-connector:
	set -x \
	&& cd ../stream-tester \
	&& make connector \
	&& cd - \
	&& cp ../stream-tester/build/mist-api-connector ./bin/livepeer-mist-api-connector

.PHONY: download
download:
	go run main.go -v=5 $(ARGS)

.PHONY: mac-dev
mac-dev:
	set -x \
	&& rm -rf /Volumes/RAMDisk/mist \
	&& TMP=/Volumes/RAMDisk ./bin/MistController -c $(HOME)/mistserver.dev.conf -g 10

.PHONY: livepeer-log
livepeer-log:
	go build -o ./bin/livepeer-log ./cmd/livepeer-log/livepeer-log.go

.PHONY: clean
clean:
	git clean -ffdx