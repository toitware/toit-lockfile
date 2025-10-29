// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import host.file
import log
import lockfile

import .utils

main:
  with-tmp-dir "/tmp/lockfile-test": | dir/string |
    lock-path := "$dir/lock"
    lock := lockfile.Lock lock-path --update-interval=(Duration --m=3)

    lock.do:
      expect (file.is-directory lock-path)

      lock2 := lockfile.Lock lock-path
          --logger=(log.default.with-name "lock2")
          --stale-duration=(Duration --ms=10)
      expect-throw "LOCK_STALE":
        lock2.do: unreachable
      expect-equals "ok" (test-stale lock2)

    expect-not (file.is-directory lock-path)

test-stale lock/lockfile.Lock -> string:
  lock.do --on-stale=(: return "ok"):
    unreachable
  return "bad"
