{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  btrfs-progs,
  gpgme,
  libassuan,
  systemd,
}: let
  pname = "prometheus-podman-exporter";
  version = "2.0.0";
in
  buildGoModule {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "containers";
      repo = pname;
      rev = "v${version}";
      hash = "sha256-713r7COiEEO+zGVQPhFoWPpr9ILYxABQrRshvF9bfVU=";
    };

    # Upstream vendors all dependencies and builds with `-mod=vendor`.
    vendorHash = null;
    proxyVendor = false;

    nativeBuildInputs = [pkg-config];
    buildInputs = [btrfs-progs gpgme libassuan systemd];

    # Mirrors the build tags selected by hack/{systemd,btrfs_installed}_tag.sh
    # when systemd and btrfs headers are available.
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
