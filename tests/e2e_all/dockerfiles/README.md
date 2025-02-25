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
    -t noports-daemon-dart:$commit_hash \
    .
```

Run the Docker image to inspect

```bash
docker run --rm -it noports-daemon-dart:$commit_hash /bin/bash
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
    -t noports-daemon-dart:$branch \
    .
```

Run the Docker image to inspect

```bash
docker run --rm -it noports-daemon-dart:$branch /bin/bash
```

## Dockerfile.c.branch

### Building from a branch Name

```bash
branch=trunk

sudo docker build \
    --build-arg branch=$branch \
    -f Dockerfile.c.branch \
    -t noports-daemon-c:$branch \
    .

sudo docker run --rm -it noports-daemon-c:$branch /bin/bash
```