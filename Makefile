#  Zenroom (GNU Makefile build system)
#
#  (c) Copyright 2017-2018 Dyne.org foundation
#  designed, written and maintained by Denis Roio <jaromil@dyne.org>
#
#  This program is free software: you can redistribute it and/or
#  modify it under the terms of the GNU General Public License version
#  3 as published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see
#  <http://www.gnu.org/licenses/>.

pwd := $(shell pwd)
ARCH=$(shell uname -m)

# include platform specific configurations pattern-matching target labels
include ${pwd}/build/config.mk

test-exec := ${pwd}/src/zenroom-shared -c ${pwd}/test/decode-test.conf

all:
	@echo "Choose a target:"
	@echo "- js-node, js-wasm, js-demo   (need EMSDK env loaded)"
	@echo "- linux, linux-lib, linux-clang, linux-debug"
	@echo "- linux-python, linux-java        (language bindings)"
	@echo "- osx			(uses default compiler on Apple/OSX)"
	@echo "- win, win-dll	(cross-compile using MINGW on Linux)"
	@echo "- musl, musl-local, musl-system   (full static build)"

	@echo "for android and ios see scripts in build/"

embed-lua:
	@echo "Embedding all files in src/lua"
	if ! [ -r build/luac ]; then ${gcc} -I${luasrc} -o build/luac ${luasrc}/luac.c ${luasrc}/liblua.a -lm; fi
	./build/embed-lualibs
	@echo "File generated: src/lualibs_detected.c"
	@echo "Must commit to git if modified, see git diff."

apply-patches:
	${pwd}/build/apply-patches

# build targets for javascript (emscripten)
include ${pwd}/build/javascript.mk

# build targets for windows (mingw32 cross compile on Linux)
include ${pwd}/build/windows.mk

# build targets for linux systems (also musl and android)
include ${pwd}/build/linux.mk

# build targets for apple systems (OSX and IOS)
include ${pwd}/build/osx.mk

# experimental target for xtensa embedded boards
esp32: apply-patches lua53 milagro lpeglabel
	CC=${pwd}/build/xtensa-esp32-elf/bin/xtensa-esp32-elf-${gcc} \
	LD=${pwd}/build/xtensa-esp32-elf/bin/xtensa-esp32-elf-ld \
	CFLAGS="${cflags}" LDFLAGS="${ldflags}" LDADD="${ldadd}" \
		make -C src linux

# static dependencies in lib
lpeglabel:
	CC=${gcc} CFLAGS="${cflags} -I${pwd}/lib/lua53/src" AR="${ar}" make -C lib/lpeglabel

zlib:
	CC=${gcc} CFLAGS="${cflags}" \
	LDFLAGS="${ldflags}" AR="${ar}" RANLIB=${ranlib} \
	pwd="${pwd}" make -C ${pwd}/build/zlib -f ZenMakefile

lua53:
	CC=${gcc} CFLAGS="${cflags} \
	-DLUA_COMPAT_5_3 -DLUA_COMPAT_MODULE" \
	LDFLAGS="${ldflags}" AR="${ar}" RANLIB=${ranlib} \
	make -C ${pwd}/lib/lua53/src ${platform}

milagro:
	@echo "-- Building milagro (${system})"
	if ! [ -r ${pwd}/lib/milagro-crypto-c/CMakeCache.txt ]; then cd ${pwd}/lib/milagro-crypto-c && CC=${gcc} AR=${ar} RANLIB=${ranlib} LD=${ld} cmake . -DCMAKE_C_FLAGS="${cflags}" -DCMAKE_SYSTEM_NAME="${system}" ${milagro_cmake_flags}; fi
	if ! [ -r ${pwd}/lib/milagro-crypto-c/lib/libamcl_core.a ]; then CC=${gcc} CFLAGS="${cflags}" AR=${ar} RANLIB=${ranlib} LD=${ld} make -C ${pwd}/lib/milagro-crypto-c VERBOSE=1; fi

check-milagro: milagro
	CC=${gcc} CFLAGS="${cflags}" make -C ${pwd}/lib/milagro-crypto-c test

# -------------------
# Test suites for all platforms
include ${pwd}/build/tests.mk

clean:
	make clean -C ${pwd}/lib/lua53/src
	make clean -C ${pwd}/lib/milagro-crypto-c && \
		rm -f ${pwd}/lib/milagro-crypto-c/CMakeCache.txt
	make clean -C ${pwd}/lib/lpeglabel
	make clean -C src
	rm -f ${extras}/index.*

distclean:
	rm -rf ${musl}
