// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import fs
import host.pipe
import monitor
import system

import .utils

PARALLEL-CLIENTS ::= 30
DURATION-MS ::= 5_000

main args:
  toit-bin := args[0]

  with-tmp-dir "/tmp/lockfile-stress": | dir/string |
    test dir toit-bin

test dir/string toit-bin/string:
  lock-path := "$dir/lock"
  resource-path := "$dir/resource"

  my-path := system.program-path
  my-dir := fs.dirname my-path
  done-semaphore := monitor.Semaphore
  PARALLEL-CLIENTS.repeat: | child-id/int |
    task::
      exit-value := pipe.run-program [
        toit-bin,
        "$my-dir/stress-test-child.toit",
        "$child-id",
        lock-path,
        resource-path,
        "$DURATION-MS",
      ]
      expect-equals 0 exit-value
      done-semaphore.up

  PARALLEL-CLIENTS.repeat: done-semaphore.down
