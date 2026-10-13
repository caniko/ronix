# ronix NixOS helpers — convenience functions for RON-configured services.
{ronixLib}: {
  ## Create a systemd service backed by a RON config file.
  ##
  ## Usage:
  ##   ronix.nixosModules.helpers.mkRonService {
  ##     name = "smartcool";
  ##     package = cfg.package;
  ##     settings = cfg.settings;
  ##     execStart = "${cfg.package}/bin/sc daemon -c /etc/smartcool/config.ron";
  ##   }
  mkRonService = {
    name,
    package,
    settings,
    execStart,
    configDir ? name,
    configFile ? "config.ron",
    serviceConfig ? {},
    wantedBy ? ["multi-user.target"],
    after ? ["local-fs.target"],
  }: {
    environment.etc."${configDir}/${configFile}".text =
      ronixLib.toRON 0 settings;

    systemd.services.${name} = {
      description = "${name} service";
      inherit wantedBy after;
      serviceConfig =
        {
          ExecStart = execStart;
          Restart = "on-failure";
        }
        // serviceConfig;
    };
  };
}
