# tests/e2e_all/dockerfiles

## Dockerfile.dart.branch

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

## Dockerfile.dart.release

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