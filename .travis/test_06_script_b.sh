#!/usr/bin/env bash
#
# Copyright (c) 2018 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.
# build trigger

export LC_ALL=C.UTF-8

cd "build/elements-$HOST" || (echo "could not enter distdir build/bitcoin-$HOST"; exit 1)

if [ "$RUN_UNIT_TESTS" = "true" ]; then
  BEGIN_FOLD unit-tests
  DOCKER_EXEC echo wolf 1
  DOCKER_EXEC apt-get upgrade clang
  DOCKER_EXEC clang --version
  DOCKER_EXEC TSAN_OPTIONS="history_size=1:memory_limit_mb=128:${TSAN_OPTIONS}" LD_LIBRARY_PATH=$TRAVIS_BUILD_DIR/depends/$HOST/lib make $MAKEJOBS check VERBOSE=1
  END_FOLD
fi

if [ "$RUN_FUNCTIONAL_TESTS" = "true" ]; then
  BEGIN_FOLD functional-tests
  DOCKER_EXEC echo wolf 2
  DOCKER_EXEC TSAN_OPTIONS="history_size=1:memory_limit_mb=128:${TSAN_OPTIONS}" test/functional/test_runner.py --ci --combinedlogslen=4000 --coverage --quiet --failfast
  END_FOLD
fi

if [ "$RUN_FUZZ_TESTS" = "true" ]; then
  BEGIN_FOLD fuzz-tests
  DOCKER_EXEC echo wolf 3
  DOCKER_EXEC test/fuzz/test_runner.py -l DEBUG ${DIR_FUZZ_IN}
  END_FOLD
fi
