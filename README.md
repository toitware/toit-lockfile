# Lockfile

A filesystem-based locking library.

When a filesystem lock is acquired, a directory is created at the specified
path. Only, one process can successfully create the directory, making it the
holder of the lock.

While holding a lock, the process periodically updates the modification time
of the lock directory. Other processes can use this to determine if the lock is
stale. If the modification time of a lock isn't updated for a certain duration,
it is considered stale which is reported when trying to acquire the lock.

When the lock is released, the directory is removed.

## Example

```toit
import lockfile
import log

main:
  lock-path := "my.lock"
  lock := lockfile.Lock lock-path
      --logger=(log.default.with-level log.FATAL-LEVEL)

  lock.do --on-stale=(: report-stale-lock lock-path):
    print "Got lock!"

report-stale-lock path:
  print "Lock at $path is stale."
  print "If you are sure no other process is using it, you can delete it."
  throw "LOCK_STALE"
```
