# tests/e2e_all/dockerfiles

- [tests/e2e_all/dockerfiles](#tests-e2e-all-dockerfiles)
  * [Dockerfile.dart.branch](#dockerfiledartbranch)
    + [1. From Commit Hash](#1-from-commit-hash)
    + [2. From Branch Name](#2-from-branch-name)
  * [Dockerfile.c.branch](#dockerfilecbranch)
    + [1. From Commit Hash](#1-from-commit-hash-1)
    + [2. From Branch Name](#2-from-branch-name-1)
  * [Dockerfile.dart.release](#dockerfiledartrelease)
    + [1. From Release Version](#1-from-release-version)
    + [2. From Latest Version](#2-from-latest-version)
  * [Dockerfile.c.release](#dockerfilecrelease)
    + [1. From Release Version](#1-from-release-version-1)

## Dockerfile.dart.branch

Below are some examples for building a Docker image with Dart binaries.

### 1. From Commit Hash

```bash
commit_hash=$(git rev-parse HEAD)
echo "Latest commit hash: $commit_hash"

sudo docker build \
    -f Dockerfile.dart.branch \
    -t noports-dart:$commit_hash \
    --build-arg branch=$commit_hash \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:$release \
    /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d dart-latest-hash -s -v
```

### 2. From Branch Name

```bash
branch="trunk"

sudo docker build \
    -f Dockerfile.dart.branch \
    -t noports-dart:$branch \
    --build-arg branch=$branch \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:$release \
    /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d dart-trunk -s -v
```

## Dockerfile.c.branch

Here are some examples of building a Docker image with C binaries.

### 1. From Commit Hash

```bash
commit_hash=$(git rev-parse HEAD)
echo "Latest commit hash: $commit_hash"

sudo docker build \
    -f Dockerfile.c.branch \
    -t noports-c:$commit_hash \
    --build-arg branch=$commit_hash \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$commit_hash \
    /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c-test -s -v
```

### 2. From Branch Name

```bash
branch=trunk

sudo docker build \
    -f Dockerfile.c.branch \
    -t noports-c:$branch \
    --build-arg branch=$branch \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$branch \
    /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c-trunk -s -v
```

## Dockerfile.dart.release

Here are some examples of running a Docker image with Dart binaries.

### 1. From Release Version

```bash
release=v5.8.7

sudo docker build \
    -f ./Dockerfile.dart.release \
    -t noports-dart:$release \
    --build-arg release=$release \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$release \
    /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d dart-v5.8.7 -s -v
```

### 2. From Latest Version

```bash
release=latest

sudo docker build \
    -f ./Dockerfile.dart.release \
    -t noports-c:$release \
    --build-arg release=$release \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:$release \
    /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d dart-latest -s -v
```

## Dockerfile.c.release

Here are some examples of running a Docker image with C binaries.

### 1. From Release Version

```bash
release=c1.0.0

sudo docker build \
    -f ./Dockerfile.c.release \
    -t noports-c:$release \
    --build-arg release=$release \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$release \
    /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c1.0.0 -s -v
```
