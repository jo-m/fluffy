{
  # Common ServiceConfig for container systemd units.
  # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
  ServiceConfig = {
    Restart = "always";
    RestartSec = "100ms";
    RestartSteps = "10";
    RestartMaxDelaySec = "60s";
  };

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
