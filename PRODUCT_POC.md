# Prodysor Terminal package POC

This branch builds packages for:

```text
application ID: com.prodysor.term
data directory: /data/data/com.prodysor.term
prefix:          /data/data/com.prodysor.term/files/usr
architecture:    aarch64
```

`scripts/build-bootstraps.sh` builds the bootstrap and its dependency closure
from local package source definitions. The generated artifact is deliberately a
non-release POC: it proves source-build and prefix viability but is not accepted
for installation until the dedicated repository public key has replaced the
upstream keys and the independently signed repository is online.

The source builder may include build-time outputs beyond the final runtime
closure. After the repository is populated, the release bootstrap will be
regenerated from that repository with `scripts/generate-bootstraps.sh` and its
explicit `--repository` option. That second archive is the one embedded in the
application and checked against the packages published by the repository.

The bootstrap must not be produced by rewriting official Termux binaries. It
must not enable any official Termux binary package repository.
