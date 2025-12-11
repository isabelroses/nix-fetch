let
  inherit (builtins)
    fetchurl
    substring
    stringLength
    readFile
    split
    filter
    match
    isString
    fromJSON
    floor
    head
    elemAt
    ;

  get = file: fetchurl "file://${file}";

  read =
    file:
    let
      contents = readFile (get file);
    in
    substring 0 ((stringLength contents) - 1) contents;

  readMemField =
    name: meminfo:
    let
      matches = filter (
        line: isString line && match "^${name}:[[:space:]]*([0-9]+) kB" line != null
      ) meminfo;
      matched = match "^${name}:[[:space:]]*([0-9]+) kB" (head matches);
    in
    fromJSON (head matched);
in

{
  kernel = read "/proc/sys/kernel/osrelease";

  distro =
    let
      raw =
        read "/etc/os-release"
        |> split "\n"
        |> filter (line: isString line && match "^PRETTY_NAME=.*" line != null)
        |> head;
    in
    substring 13 ((stringLength raw) - 14) raw;

  shell =
    let
      uid =
        read "/proc/self/status"
        |> split "\n"
        |> filter (
          line:
          isString line
          &&
            match "^Uid:[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+$" line != null
        )
        |> head
        |> split "\t"
        |> (a: elemAt a 2);

      result =
        read "/etc/passwd"
        |> split "\n"
        |> filter (line: isString line && match ".*:.*:${uid}:.*" line != null)
        |> head
        |> split ":"
        |> (a: elemAt a 12);
    in
    result;
  #
  # term = get "/proc/self/fd/0";
  #
  memory =
    let
      meminfo = split "\n" (read "/proc/meminfo");
      total = readMemField "MemTotal" meminfo;
      available = readMemField "MemAvailable" meminfo;

      used = total - available;

      percent = if total == null then null else (used * 100) / total;

      toGiB = kb: (kb / 1024.0) / 1024.0 |> builtins.toString |> builtins.substring 0 5;
    in
    "${toGiB used} GiB / ${toGiB total} GiB (${toString percent}%)";

  uptime =
    let
      inp = read "/proc/uptime";
      secondsStr = head (split " " inp);

      uptime_seconds = floor (fromJSON secondsStr);
      days = uptime_seconds / 86400;
      rem1 = uptime_seconds - (days * 86400);
      hours = rem1 / 3600;
      rem2 = rem1 - (hours * 3600);
      minutes = rem2 / 60;

      result =
        if days > 0 then
          "${toString days} days, ${toString hours} hours"
        else if hours > 0 then
          "${toString hours} hours, ${toString minutes} mins"
        else
          "${toString minutes} mins";
    in
    result;
}
