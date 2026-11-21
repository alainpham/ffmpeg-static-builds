# Static FFmpeg builds

Build musl-linked `ffmpeg` and `ffprobe` binaries for Linux in Docker. The Dockerfile compiles FFmpeg and several codec libraries from source and links them with static libraries from Alpine packages.

## Prerequisites

- Docker with BuildKit enabled and access to a running Docker daemon.
- A Linux environment that can run binaries for the build architecture. The script runs the exported `ffmpeg` to report its build configuration.
- The host `file` command for linkage checks. The script also uses `readelf` when available.
- Network access from Docker to pull Alpine, install packages, and fetch upstream sources.

## Build

```sh
./build-static-ffmpeg.sh --stable
./build-static-ffmpeg.sh --latest
```

| Mode | Alpine image | FFmpeg and source-built libraries |
| --- | --- | --- |
| `--stable` (default) | Pinned Alpine release | Pinned upstream release tarballs or tags |
| `--latest` | `alpine:latest` | Current upstream `main` or `master` branches |

Latest mode pulls the base image and bypasses Docker's build cache. Edit the stable pins or branch names in [build-static-ffmpeg.sh](build-static-ffmpeg.sh).

Both modes export `ffmpeg` and `ffprobe` to `./out/` in this repository. Set `OUT` to keep both builds side by side.

```sh
OUT=./out/stable ./build-static-ffmpeg.sh --stable
OUT=./out/latest ./build-static-ffmpeg.sh --latest
```

The script also accepts `DOCKERFILE` to use another Dockerfile and `TAG` to set the Docker build tag.

## Inspect the binaries

```sh
./out/ffmpeg -version
./out/ffmpeg -buildconf
./out/ffprobe -version
file ./out/ffmpeg ./out/ffprobe
```

The default build enables FDK AAC and sets FFmpeg's `--enable-nonfree` option.
