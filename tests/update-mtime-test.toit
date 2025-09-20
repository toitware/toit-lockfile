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
    lock := lockfile.Lock lock-path --update-interval=(Duration --ms=10)

    lock2-done-latch := monitor.Latch
    lock.do:
      expect (file.is-directory lock-path)

      task::
        lock2 := lockfile.Lock lock-path
            --logger=(log.default.with-name "lock2")
            --stale-duration=(Duration --ms=20)
        lock2.do:
          print "got lock"
        lock2-done-latch.set true

      sleep --ms=300

    lock2-done-latch.get
    expect-not (file.is-directory lock-path)
