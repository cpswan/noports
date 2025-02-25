# tests/e2e_all/dockerfiles

## Dockerfile.dart.branch

### Building from a Commit Hash

Get a commit hash

```bash
commit_hash=$(git rev-parse HEAD)
echo "Latest commit hash: $commit_hash"
```

Build the Docker image

```bash
sudo docker build \
    --build-arg branch=$commit_hash \
    -f Dockerfile.dart.branch \
    -t noports-dart:$commit_hash \
    .
```

Run the Docker image to inspect

```bash
docker run --rm -it noports-dart:$commit_hash /bin/bash
```

### Building from a Branch Name

Get a branch name

```bash
branch="trunk"
echo "Branch name: $branch"
```

Build the Docker image

```bash
sudo docker build \
    --build-arg branch=$branch \
    -f Dockerfile.dart.branch \
    -t noports-dart:$branch \
    .
```

Run the Docker image to inspect

```bash
docker run --rm -it noports-dart:$branch /bin/bash
```

## Dockerfile.dart.branch

### Building from a branch Name

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

sudo docker run --rm -it noports-dart:$release /bin/bash
```

## Dockerfile.c.release

```bash
release=c1.0.0

sudo docker build \
    --build-arg release=$release \
    -f ./Dockerfile.c.release \
    -t noports-c:$release \
    .

sudo docker run --rm -it noports-c:$release /bin/bash
```