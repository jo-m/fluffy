{
  # Common ServiceConfig for container systemd units.
  # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
  ServiceConfig = {
    Restart = "always";
    RestartSec = "100ms";
    RestartSteps = "10";
    RestartMaxDelaySec = "60s";
  };
}
