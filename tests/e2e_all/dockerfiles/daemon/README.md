# tests/e2e_all/dockerfiles

## Dockerfile.build.branch.dart.noports

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
    -f Dockerfile.build.branch.dart.noports \
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
    -f Dockerfile.build.branch.dart.noports \
    -t noports-daemon-dart:$branch \
    .
```

Run the Docker image to inspect

```bash
docker run --rm -it noports-daemon-dart:$branch /bin/bash
```
