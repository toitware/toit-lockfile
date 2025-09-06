// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import fs
import host.directory
import host.file

/**
Library to take a filesystem-based lock.

Uses 'mkdir' to create a lock in the specified path. If the lock already
  exists waits until the other process has released it. To avoid blocking
  on stale locks uses the directory's 'mtime' to determine when the lock
  was last used.

Uses polling to check whether a lock is still held. If multiple processes
  are trying to take the lock, the order in which they succeed is
  undefined. The lock is not reentrant, so if a process tries to take the
  lock while it already holds it, it will block until the lock is released.
*/

/**
A lock.

Typically, users don't use this class directly, but rather use $with-lock.
*/
class Lock:
  path/string
  task_/Task? := ?
  we-own/bool := false

  /**
  Takes the lock at the specified $path.

  Throws an exception if the $path already exists and is not a directory.
  */
  constructor .path:
    task_ := task::
      while true:
        if we-own:
          // Update the mtime of the lock to indicate that we are still using it.
          file.

    if file.is-directory path:
      // There is already a directory.



