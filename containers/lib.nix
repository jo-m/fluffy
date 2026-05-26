{
  # Common ServiceConfig for container systemd units.
  # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
  ServiceConfig = {
    Restart = "always";
    RestartSec = "100ms";
    RestartSteps = "10";
    RestartMaxDelaySec = "60s";
  };

  # Hash of the encrypted sops secrets file. Inject into a container's
  # environments/labels so that any secret change alters the generated
  # systemd unit text, causing sd-switch to restart the container. Without
  # this, edits to secrets.yaml only change the rendered file's contents
  # while its path stays stable, so the unit hash is unchanged.
  sopsFingerprint = builtins.hashFile "sha256" ../secrets.yaml;

  # Generate podfather app discovery labels for a container.
  # Takes an attrset with: name (required), icon, category, sort-index, description, url (all optional).
  # Returns a list of "ch.jo-m.go.podfather.app.<field>=<value>" strings.
  podfatherLabels = {
    name,
    icon ? null,
    category ? null,
    sort-index ? null,
    description ? null,
    url ? null,
  }: let
    prefix = "ch.jo-m.go.podfather.app";
    optionalLabel = field: value:
      if value != null
      then ["${prefix}.${field}=${value}"]
      else [];
  in
    ["${prefix}.name=${name}"]
    ++ optionalLabel "icon" icon
    ++ optionalLabel "category" category
    ++ optionalLabel "sort-index" sort-index
    ++ optionalLabel "description" description
    ++ optionalLabel "url" url;
}
