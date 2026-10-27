# DevOps CI Tool

A Linux diagnostic command-line tool with a full local CI pipeline. The tool is a
single Bash dispatcher (`app/app.sh`); the surrounding scripts lint it, test it,
and package it into a Docker image, and a GitHub Actions workflow runs those
stages in order on every push and pull request.

## Requirements

- Bash, Docker (with Compose v2), and optionally `shellcheck` for local linting.

## Application usage

```bash
./app/app.sh system-info
./app/app.sh check-host example.com
./app/app.sh check-port example.com 443
./app/app.sh help
```

| Command                     | Description                                | Exit codes |
|-----------------------------|--------------------------------------------|------------|
| `system-info`               | Show hostname, user, OS, kernel, uptime, CPU, memory, cwd | `0` |
| `check-host <host>`         | Resolve a host and test reachability       | `0` reachable, `1` unreachable, `2` missing host |
| `check-port <host> <port>`  | Validate the port and test TCP connectivity | `0` open, `1` closed, `2` invalid/missing input |
| `help`                      | Show usage                                 | `0` |

Exit-code contract: `0` success, `1` operational failure, `2` invalid command or
input. Running the tool with no command is an error (`2`).

## Local workflows

```bash
./scripts/lint.sh     # verify files exist and scripts parse (+ shellcheck if present)
./tests/test.sh       # run the CLI assertions
./scripts/build.sh    # build the image and smoke-test the container
```

## Docker

```bash
docker build -t devops-tool .
docker run --rm devops-tool help
docker run --rm devops-tool system-info
```

A `devops-tool` service is also defined in `compose.yaml`:

```bash
docker compose config        # validate the configuration
docker compose run --rm devops-tool system-info
```

## CI pipeline

`.github/workflows/ci.yml` defines three jobs that run on every `push` and
`pull_request`, in order:

```
validate  ->  test  ->  docker
```

- **validate** runs `scripts/lint.sh` (and installs `shellcheck`).
- **test** runs `tests/test.sh`. It declares `needs: validate`, so it only starts
  after validate succeeds.
- **docker** runs `scripts/build.sh` to build and smoke-test the image. It
  declares `needs: test`, so it only starts after test succeeds.

The `needs:` dependencies enforce the order: a failure at an earlier stage stops
the pipeline before the later, more expensive stages run.

## CI failure demonstration

The project history includes a demonstration that the pipeline catches
regressions. On the `feature/ci-pipeline` branch, one commit introduced a
deliberate syntax error in `app/app.sh`, which made the `validate` job fail. A
later commit on the same branch fixed the error, after which the pipeline passed.
The fix was committed before the branch was merged into `main`, so `main` remains
green.

## Testing and grading

```bash
chmod +x grade.sh app/*.sh scripts/*.sh tests/*.sh
./grade.sh
```

The grader runs on a host with Docker available; it builds the image and runs the
container commands itself.

## Assumptions

- The image is based on `ubuntu:22.04` and installs only the packages the tool
  needs (`iproute2`, `iputils-ping`, `dnsutils`, `netcat-openbsd`, `procps`).
- `tests/test.sh` runs `app/app.sh` directly (no container), so the CI test job
  needs no Docker; only the docker job builds the image.
- The port check prefers Bash's `/dev/tcp`, falling back to `nc` when available.
- No secrets or machine-specific values are stored in the repository.
