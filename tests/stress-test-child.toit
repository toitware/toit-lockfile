// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import host.file
import lockfile
import log

main args:
  id/string := args[0]
  lock-path := args[1]
  resource-path := args[2]
  duration-ms := int.parse args[3]

  start := Time.monotonic-us

  logger := log.default.with-level log.FATAL-LEVEL
  lock := lockfile.Lock lock-path --logger=logger --poll-interval=(Duration --ms=1)

  id-bytes := id.to-byte-array
  count := 0
  while Time.monotonic-us - start < duration-ms * 1000:
    count++
    lock.do:
      expect-not (file.is-file resource-path)
      file.write-contents --path=resource-path id
      contents := file.read-contents resource-path
      expect-equals id-bytes contents
      file.delete resource-path
    sleep --ms=1

  print "Done $id - $count"
