# test

A starter project to extend the base bootc image from:

- `quay.io/hummingbird-community/bootc-os`

This project layers desktop packages on top of that base image and produces a new bootc image tag.

## Project Layout

- `Containerfile`: image extension logic
- `packages/base-desktop.txt`: package manifest to install
- `compose.yaml`: optional compose-based build
- `scripts/build.sh`: one-command build script
- `scripts/build-disk.sh`: build a local qcow2 from the local image
- `scripts/run-qemu.sh`: boot the generated qcow2 in QEMU
- `.github/workflows/publish-ghcr.yml`: publish image to GHCR on pushes/tags

## Prerequisites

- Docker installed
- Access to pull `quay.io/hummingbird-community/bootc-os`

## Quick Start

1. Copy env file:

```bash
cp .env.example .env
```

2. Edit package list in `packages/base-desktop.txt`.

3. Build image:

```bash
./scripts/build.sh
```

4. Optional: enable Fedora Rawhide + COPR by setting these in `.env`:

```bash
ENABLE_FEDORA_RAWHIDE_REPO=1
COPR_REPO=owner/project
COPR_CHROOT=fedora-rawhide-x86_64
```

## Build with Compose

```bash
docker compose build
```

## Build directly

```bash
docker build -f Containerfile -t localhost/test:latest .
```

## User Creation (Recommended)

For bootc images, create login users at install/image-build time with a blueprint instead of baking users into the base image.

- Example blueprint file: `blueprint/user-example.toml`
- This keeps credentials and SSH keys out of the shared image layer.

Example with `bootc-image-builder`:

```bash
docker save localhost/test:latest | podman load

podman run --rm --privileged \
	--pull=never \
	--security-opt label=type:unconfined_t \
	-v "$(pwd)/blueprint/user-example.toml:/config.toml:ro" \
	-v "$(pwd)/output:/output" \
	-v /var/lib/containers/storage:/var/lib/containers/storage \
	quay.io/centos-bootc/bootc-image-builder:latest \
	build \
	--type qcow2 \
	--rootfs ext4 \
	--use-librepo=True \
	localhost/test:latest
```

Before running, replace the placeholder password hash or SSH key and set your preferred username.

## Local Testing

Build everything locally with the provided scripts:
and test locally with the provided scripts:

```bash
./scripts/build.sh
./scripts/build-disk.sh
./scripts/run-qemu.sh
```

To test on real hardware, burn the qcow2 disk image directly to a USB stick:

```bash
./scripts/build.sh
./scripts/build-disk.sh
# Check device name with: lsblk
sudo dd if=output/qcow2/disk.qcow2 of=/dev/sdX bs=4M status=progress
sudo sync
# Boot from USB stick to start the installed system
```

Notes:

- `scripts/build-disk.sh` copies your local Docker image into local Podman storage and creates `output/qcow2/disk.qcow2`.
- Both the qcow2 and USB-burned image are bootable.
- The script auto-detects rootless Podman, switches to `--in-vm` mode automatically, and uses local cache directories under `.cache/`.
- `scripts/run-qemu.sh` boots the newest qcow2 it finds under `output/`.
- QEMU forwards `localhost:2222` to guest port `22` for optional SSH testing later.
- On SELinux systems, `osbuild-selinux` may be required on the host for `bootc-image-builder` to complete successfully.
- On Debian, if rootless Podman fails with `chcon /store` errors, run `PODMAN_USE_SUDO=1 ./scripts/build-disk
With COPR enabled:

```bash
docker build \
	--build-arg ENABLE_FEDORA_RAWHIDE_REPO=1 \
	--build-arg COPR_REPO=owner/project \
	--build-arg COPR_CHROOT=fedora-rawhide-x86_64 \
	-f Containerfile \
	-t localhost/test:latest .
```

## Customization Tips

- Add packages to `packages/base-desktop.txt` for your target desktop stack.
- Use `COPR_REPO=owner/project` when you need packages not in the base repos.
- Set `ENABLE_FEDORA_RAWHIDE_REPO=1` when you need Fedora Rawhide package metadata during build.
- Use `COPR_CHROOT=...` if COPR reports chroot not found (for example `fedora-43-x86_64`).
- Keep optional/experimental packages commented until you verify repo availability.
- If your base distro does not use `dnf`, adjust the package install step in `Containerfile`.

## Next Steps

- Push your image to a registry:

```bash
docker push localhost/test:latest
```

- Use your resulting image with your bootc deployment flow.

## Publish to GHCR

You can host this project on GitHub and automatically publish your bootc image to GHCR.

1. Create a GitHub repository and push this project:

```bash
git init
git add .
git commit -m "Initial bootc desktop image project"
git branch -M main
git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git
git push -u origin main
```

2. The workflow in `.github/workflows/publish-ghcr.yml` will publish to:

```text
ghcr.io/YOUR_USER/YOUR_REPO
```

3. Optional: set repository variables in GitHub (Settings -> Secrets and variables -> Actions -> Variables):

- `ENABLE_FEDORA_RAWHIDE_REPO` (example: `1`)
- `COPR_REPO` (example: `avengemedia/dms`)
- `COPR_CHROOT` (example: `fedora-rawhide-x86_64`)

4. Make the package visible to the systems that need it:

- For easiest testing, set the GHCR package visibility to public.
- For private packages, configure auth on target systems.

## bootc Upgrade Flow

Once published, point your machine at GHCR and upgrade from there.

Initial switch:

```bash
sudo bootc switch ghcr.io/YOUR_USER/YOUR_REPO:latest
sudo systemctl reboot
```

After you push updates and CI publishes a new image:

```bash
sudo bootc upgrade
sudo systemctl reboot
```
