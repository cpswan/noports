# tests/e2e_all/dockerfiles

## Dockerfile.dart.branch


```bash
commit_hash=$(git rev-parse HEAD)
echo "Latest commit hash: $commit_hash"

sudo docker build \
    --build-arg branch=$commit_hash \
    -f Dockerfile.dart.branch \
    -t noports-dart:$commit_hash \
    .

sudo docker run --rm -it noports-dart:$commit_hash /bin/bash
```

```bash
branch="trunk"

sudo docker build \
    --build-arg branch=$branch \
    -f Dockerfile.dart.branch \
    -t noports-dart:$branch \
    .

docker run --rm -it noports-dart:$branch /bin/bash
```

## Dockerfile.c.branch

```bash
branch=trunk

sudo docker build \
    --build-arg branch=$branch \
    -f Dockerfile.c.branch \
    -t noports-c:$branch \
    .

sudo docker run --rm -it noports-c:$branch /bin/bash
```

## Dockerfile.dart.release

```bash
release=v5.8.7

sudo docker build \
    --build-arg release=$release \
    -f ./Dockerfile.dart.release \
    -t noports-dart:$release \
    .

sudo docker run --rm -it noports-dart:$release /bin/bash
```

```bash
release=latest

sudo docker build \
    --build-arg release=$release \
    -f ./Dockerfile.dart.release \
    -t noports-c:$release \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$release \
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