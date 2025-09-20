// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import host.file
import log
import lockfile
import monitor

import .utils

main:
  with-tmp-dir "/tmp/lockfile-test": | dir/string |
    lock-path := "$dir/lock"
    lock := lockfile.Lock lock-path

    lock2-done-latch := monitor.Latch
    lock.do:
      expect (file.is-directory lock-path)

      lock2 := lockfile.Lock lock-path --logger=(log.default.with-name "lock2")
      expect-throw DEADLINE-EXCEEDED-ERROR:
        with-timeout --ms=3:
          lock2.do:
            // We should never be able to get here.
            expect false

      task::
        lock2.do:
          // Do nothing.
          print "Got lock"
          null
        lock2-done-latch.set true

    lock2-done-latch.get
    expect-not (file.is-directory lock-path)
