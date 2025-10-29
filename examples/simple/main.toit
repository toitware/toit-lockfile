// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/EXAMPLES_LICENSE file.

import lockfile
import log

/**
Demonstrates the basic usage of the lockfile library.
*/

main args:
  name := args[0]
  lock-path := args[1]
  lock := lockfile.Lock lock-path
      --logger=(log.default.with-level log.FATAL-LEVEL)

  lock.do --on-stale=(: report-stale-lock lock-path):
    print "$name: got lock!"
    sleep --ms=1000
    print "$name: releasing lock."

report-stale-lock path:
  print "Lock at $path is stale."
  print "If you are sure no other process is using it, you can delete it."
  throw "LOCK_STALE"
