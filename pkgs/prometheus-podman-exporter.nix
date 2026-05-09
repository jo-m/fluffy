{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  btrfs-progs,
  gpgme,
  libassuan,
  lvm2,
  systemd,
}: let
  pname = "prometheus-podman-exporter";
  version = "1.21.0";
in
  buildGoModule {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "containers";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-HY9ZOooAlIF3vb7ZENpRGvW5074PQS8yrfFXG39/Ycw=";
    };

    # Upstream vendors all dependencies and builds with `-mod=vendor`.
    vendorHash = null;
    proxyVendor = false;

    nativeBuildInputs = [pkg-config];
    buildInputs = [btrfs-progs gpgme libassuan lvm2 systemd];

    # Mirrors the build tags selected by hack/{systemd,btrfs,btrfs_installed}_tag.sh
    # when systemd headers and full btrfs (with version.h) are available.
    tags = ["systemd"];

    ldflags = [
      "-X github.com/containers/prometheus-podman-exporter/cmd.buildVersion=${version}"
      "-X github.com/containers/prometheus-podman-exporter/cmd.buildRevision=nixpkgs"
      "-X github.com/containers/prometheus-podman-exporter/cmd.buildBranch=release"
    ];

    subPackages = ["."];

    meta = {
      description = "Prometheus exporter for Podman environment exposing containers, pods, images, volumes and networks information";
      homepage = "https://github.com/containers/${pname}";
      license = lib.licenses.asl20;
      mainProgram = pname;
      platforms = lib.platforms.linux;
    };
  }
