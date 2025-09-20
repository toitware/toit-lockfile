// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import fs
import host.directory
import host.file
import monitor
import log

/**
Library to take a filesystem-based lock.

Uses 'mkdir' to create a lock in the specified path. If the lock already
  exists waits until the other process has released it. Detects stale
  locks by using the directory's 'mtime' to determine when the lock
  was last used.

Uses polling to check whether a lock is still held. If multiple processes
  are trying to take the lock, the order in which they succeed is
  undefined. The lock is not reentrant, so if a process tries to take the
  lock while it already holds it, it will block until the lock is released.
*/

/**
A filesystem lock.
*/
class Lock:
  static STATE-CREATED_ ::= 0
  static STATE-TAKING_ ::= 1
  static STATE-OWNED_ ::= 2
  static STATE-RELEASING_ ::= 3

  static TOO-MANY-CREATION-FAILURES_ ::= 50

  path/string

  logger_/log.Logger
  poll-interval/Duration
  update-interval/Duration
  stale-duration/Duration

  // Latch for whether a `do` is done.
  done-latch_/monitor.Latch? := null

  /**
  Takes the lock at the specified $path.

  Throws an exception if the $path already exists and is not a directory.
  */
  constructor .path
      --logger/log.Logger=log.default
      --.poll-interval/Duration=(Duration --ms=10)
      --.update-interval/Duration=(poll-interval * 3)
      --.stale-duration/Duration=(Duration --ms=(max (update-interval.in-ms * 3) 1000)):
    logger_ = logger.with-name "filelock"

  /**
  Variant of $(do [--if-stale] [block]) that throws an error if the
    lock is stale.
  */
  do [block] -> none:
    do block --if-stale=: throw "LOCK_STALE"

  /**
  Runs the given $block while holding the lock.
  If the lock is already held by another process, waits until it is released.
  Checks every $poll-interval whether the lock is available.
  If the lock is stale (not updated for $stale-duration) calls the $if-stale
    block with the $path as argument.
  When holding the lock, updates its mtime every $update-interval to
    prevent it from becoming stale.
  */
  do [--if-stale] [block] -> none:
    try:
      if done-latch_:
        throw "INVALID_STATE"
      done-latch_ = monitor.Latch
      update-task := take_ --if-stale=if-stale
      try:
        block.call
      finally:
        release_ --update-task=update-task
    finally:
      done-latch_ = null

  take_ [--if-stale] -> Task:
    unchanged := 0
    last-update-time/Time? := null
    // We need to see the lock unchanged for stale-factor iterations before
    // we consider it stale.
    // We don't just check for mtime.to-now, as the computer could be put to
    // sleep and then wake up again, making the mtime appear stale, while
    // another process could still be holding the lock.
    stale-factor/int := ?
    if poll-interval.is-zero:
      stale-factor = 10
    else:
      stale-factor = max (stale-duration.in-ms / poll-interval.in-ms) 2
    stale-count := 0
    creation-failures := 0
    while true:
      stat := file.stat path
      if stat and stat[file.ST-TYPE] == file.DIRECTORY:
        creation-failures = 0
        mtime/Time := stat[file.ST-MTIME]
        if last-update-time == mtime:
          stale-count++
        else:
          last-update-time = mtime
          stale-count = 0
        if stale-count >= stale-factor and last-update-time.to-now > stale-duration:
          logger_.info "stale lock detected" --tags={"path": path}
          if-stale.call path
          // Typically we don't return from the if-stale call, but if we do,
          // we assume that the user has resolved the stale lock situation,
          // and we try to take the lock again.
          stale-count = 0
          continue

        // The lock is not stale yet. Wait and try again.
        logger_.debug "lock held by another process" --tags={"path": path}
        sleep poll-interval
        continue

      // Try to create the lock directory.
      // If the entry already existed, don't try to catch the exception, as
      //   this is an invalid state in the filesystem, and reporting the error
      //   gives the user more information.
      e := catch --unwind=(: stat != null or it != "ALREADY_EXISTS"):
        directory.mkdir path
      if e:
        // We failed to create the lock directory. Someone else was faster than us.
        creation-failures++
        if creation-failures > TOO-MANY-CREATION-FAILURES_:
          // Something is wrong. We shouldn't fail TOO-MANY-CREATION-FAILURES_ times in a row.
          logger_.error "too many failures to create lock" --tags={"path": path}
          throw "INTERNAL_ERROR"
        continue
      // We own the lock now.
      break

    logger_.info "acquired lock" --tags={"path": path}

    return task::
      try:
        e := catch:
          while true:
            sleep update-interval
            // Update the mtime of the lock to indicate that we are still using it.
            logger_.debug "updating lock mtime" --tags={"path": path}
            file.update-time path --modification=Time.now
        if e:
          logger_.error "update task failed" --tags={"path": path, "error": e}
      finally:
        critical-do --no-respect-deadline:
          done-latch_.set true

  release_ --update-task/Task -> none:
    critical-do --no-respect-deadline:
      update-task.cancel
      done-latch_.get
      if file.is-directory path:
        directory.rmdir path
        logger_.info "released lock" --tags={"path": path}
      else:
        logger_.warn "lock directory already removed" --tags={"path": path}
      done-latch_ = null

/**
Variant of $(with-lock path [--if-stale] [block]) that throws an error if the
  lock is stale.
*/
with-lock path/string
    --logger/log.Logger=log.default
    --poll-interval/Duration=Duration --ms=10
    --update-interval/Duration=(poll-interval * 3)
    --stale-duration/Duration=(Duration --ms=(max (update-interval.in-ms * 3) 1000))
    [block]:
  with-lock path
      --logger=logger
      --poll-interval=poll-interval
      --update-interval=update-interval
      --stale-duration=stale-duration
      --if-stale=: throw "LOCK_STALE"
      block

/**
Runs the given $block with a lock on the specified $path.

If the lock is already held by another process, waits until it is released.
Checks every $poll-interval whether the lock is available.
If the lock is stale (not updated for $stale-duration) calls the $if-stale block
  with the $path as argument.

When holding the lock, updates its mtime every $update-interval to
  prevent it from becoming stale.
*/
with-lock path/string
    --logger/log.Logger?=null
    --poll-interval/Duration?=null
    --update-interval/Duration?=null
    --stale-duration/Duration?=null
    [--if-stale]
    [block]:
  lock := Lock path
      --logger=logger
      --poll-interval=poll-interval
      --update-interval=update-interval
      --stale-duration=stale-duration
  lock.do block --if-stale=if-stale
