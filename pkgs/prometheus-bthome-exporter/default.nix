{
  lib,
  python314,
  stdenv,
  makeWrapper,
}: let
  python = python314.withPackages (ps: [
    ps.bthome-ble
    ps.bleak
    ps.habluetooth
    ps.prometheus-client
  ]);
in
  stdenv.mkDerivation {
    pname = "prometheus-bthome-exporter";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [python makeWrapper];

    dontBuild = true;

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      python -m unittest -v test_bthome_scan test_prometheus_bthome_exporter test_bthome_watch
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -Dm644 bthome_scan.py $out/lib/prometheus-bthome-exporter/bthome_scan.py
      install -Dm755 prometheus_bthome_exporter.py $out/bin/prometheus-bthome-exporter
      install -Dm755 bthome_watch.py $out/bin/bthome-watch
      patchShebangs $out/bin/prometheus-bthome-exporter $out/bin/bthome-watch
      wrapProgram $out/bin/prometheus-bthome-exporter \
        --prefix PYTHONPATH : $out/lib/prometheus-bthome-exporter
      wrapProgram $out/bin/bthome-watch \
        --prefix PYTHONPATH : $out/lib/prometheus-bthome-exporter
      runHook postInstall
    '';

    meta = {
      description = "Prometheus exporter and RSSI watcher for BTHome BLE sensors";
      license = lib.licenses.mit;
      mainProgram = "prometheus-bthome-exporter";
      platforms = lib.platforms.linux;
    };
  }
