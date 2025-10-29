# Simple lockfile

This example demonstrates the basic usage of the `lockfile` library to create a
simple lockfile.

Run the example twice to exercise the locking behavior:

```bash
toit main.toit Example1 /tmp/lockfile.lock &
toit main.toit Example2 /tmp/lockfile.lock
```

Alternatively, you can run each instance in a separate terminal.
