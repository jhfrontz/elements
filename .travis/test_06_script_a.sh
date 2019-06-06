#!/usr/bin/env bash
#
# Copyright (c) 2018 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

export LC_ALL=C.UTF-8

TRAVIS_COMMIT_LOG=$(git log --format=fuller -1)
export TRAVIS_COMMIT_LOG

OUTDIR=$BASE_OUTDIR/$TRAVIS_PULL_REQUEST/$TRAVIS_JOB_NUMBER-$HOST
BITCOIN_CONFIG_ALL="--disable-dependency-tracking --prefix=$TRAVIS_BUILD_DIR/depends/$HOST --bindir=$OUTDIR/bin --libdir=$OUTDIR/lib"
if [ -z "$NO_DEPENDS" ]; then
  DOCKER_EXEC ccache --max-size=$CCACHE_SIZE
fi

DOCKER_EXEC apt-get update clang
DOCKER_EXEC clang --version

BEGIN_FOLD autogen
if [ -n "$CONFIG_SHELL" ]; then
  DOCKER_EXEC "$CONFIG_SHELL" -c "./autogen.sh"
else
  DOCKER_EXEC ./autogen.sh
fi
END_FOLD

mkdir build
cd build || (echo "could not enter build directory"; exit 1)

BEGIN_FOLD configure
DOCKER_EXEC ../configure --cache-file=config.cache $BITCOIN_CONFIG_ALL $BITCOIN_CONFIG || ( cat config.log && false)
END_FOLD

BEGIN_FOLD distdir
DOCKER_EXEC make distdir VERSION=$HOST
END_FOLD

cd "elements-$HOST" || (echo "could not enter distdir elemenst-$HOST"; exit 1)

BEGIN_FOLD configure
DOCKER_EXEC ./configure --cache-file=../config.cache $BITCOIN_CONFIG_ALL $BITCOIN_CONFIG || ( cat config.log && false)
END_FOLD

set -o errtrace
trap 'DOCKER_EXEC "cat ${TRAVIS_BUILD_DIR}/sanitizer-output/* 2> /dev/null"' ERR

BEGIN_FOLD build
DOCKER_EXEC make $MAKEJOBS $GOAL || ( echo "Build failure. Verbose build follows." && DOCKER_EXEC make $GOAL V=1 ; false )
END_FOLD

if [ "${UNDEFINED_VAR}" = "true" ]; then
  BEGIN_FOLD unit-tests
  DOCKER_EXEC LD_LIBRARY_PATH=$TRAVIS_BUILD_DIR/depends/$HOST/lib make $MAKEJOBS check VERBOSE=1
  END_FOLD
fi

if [ "$TRAVIS_EVENT_TYPE" = "cron" ]; then
  extended="--extended --exclude feature_pruning"
fi

if [ "$RUN_FUNCTIONAL_TESTS" = "true" ]; then
  BEGIN_FOLD functional-tests
  DOCKER_EXEC echo wolf 11
  DOCKER_EXEC echo TSAN_OPTIONS="history_size=1:memory_limit_mb=128:${TSAN_OPTIONS}" test/functional/test_runner.py --ci --combinedlogslen=4000 --coverage --quiet --failfast ${extended}
  END_FOLD
fi

if [ "$RUN_BITCOIN_TESTS" = "true" ]; then
    BEGIN_FOLD bitcoin-functional-tests
    DOCKER_EXEC echo test/bitcoin_functional/functional/test_runner.py --combinedlogslen=4000 --coverage --quiet --failfast ${extended}
    END_FOLD
fi

if [ "${UNDEFINED_VAR}" = "true" ]; then
    BEGIN_FOLD fedpeg-bitcoind-test
    BITCOIND_VERSION=0.18.0
    BITCOIND_ARCH=x86_64-linux-gnu
    DOCKER_EXEC curl -O https://bitcoincore.org/bin/bitcoin-core-$BITCOIND_VERSION/bitcoin-$BITCOIND_VERSION-$BITCOIND_ARCH.tar.gz
    DOCKER_EXEC tar -zxf bitcoin-$BITCOIND_VERSION-$BITCOIND_ARCH.tar.gz
    DOCKER_EXEC test/functional/feature_fedpeg.py --parent_bitcoin --parent_binpath $(pwd)/bitcoin-$BITCOIND_VERSION/bin/bitcoind
    END_FOLD
fi

cd ${TRAVIS_BUILD_DIR} || (echo "could not enter travis build dir $TRAVIS_BUILD_DIR"; exit 1)
