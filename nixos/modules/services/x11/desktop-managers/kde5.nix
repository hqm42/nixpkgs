{ config, lib, pkgs, ... }:

with lib;

let

  xcfg = config.services.xserver;
  cfg = xcfg.desktopManager.kde5;
  xorg = pkgs.xorg;

  kde5 = pkgs.kde5;

in

{
  options = {

    services.xserver.desktopManager.kde5 = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the Plasma 5 (KDE 5) desktop environment.";
      };

    };

  };


  config = mkIf (xcfg.enable && cfg.enable) {

    warnings = optional config.services.xserver.desktopManager.kde4.enable
      "KDE 4 should not be enabled at the same time as KDE 5";

    services.xserver.desktopManager.session = singleton {
      name = "kde5";
      bgSupport = true;
      start = ''
        # Load PulseAudio module for routing support.
        # See http://colin.guthr.ie/2009/10/so-how-does-the-kde-pulseaudio-support-work-anyway/
        ${optionalString config.hardware.pulseaudio.enable ''
          ${getBin config.hardware.pulseaudio.package}/bin/pactl load-module module-device-manager "do_routing=1"
        ''}

        exec "${kde5.startkde}"

      '';
    };

    security.setuidOwners = [
      {
        program = "kcheckpass";
        source = "${kde5.plasma-workspace}/lib/libexec/kcheckpass";
        owner = "root";
        setuid = true;
      }
      {
        program = "start_kdeinit_wrapper";
        source = "${kde5.plasma-workspace}/lib/libexec/kf5/start_kdeinit_wrapper";
        owner = "root";
        setuid = true;
      }
    ];

    environment.systemPackages =
      [
        kde5.frameworkintegration
        kde5.kinit

        kde5.breeze
        kde5.kde-cli-tools
        kde5.kdeplasma-addons
        kde5.kgamma5
        kde5.khelpcenter
        kde5.khotkeys
        kde5.kinfocenter
        kde5.kmenuedit
        kde5.kscreen
        kde5.ksysguard
        kde5.kwayland
        kde5.kwin
        kde5.kwrited
        kde5.milou
        kde5.oxygen
        kde5.polkit-kde-agent
        kde5.systemsettings

        kde5.plasma-desktop
        kde5.plasma-workspace
        kde5.plasma-workspace-wallpapers

        kde5.dolphin
        kde5.dolphin-plugins
        kde5.ffmpegthumbs
        kde5.kdegraphics-thumbnailers
        kde5.kio-extras
        kde5.konsole
        kde5.print-manager

        # Oxygen icons moved to KDE Frameworks 5.16 and later.
        (kde5.oxygen-icons or kde5.oxygen-icons5)
        pkgs.hicolor_icon_theme

        kde5.kde-gtk-config

        pkgs.phonon-backend-gstreamer
        pkgs.kde5.phonon-backend-gstreamer
      ]

      # Plasma 5.5 and later has a Breeze GTK theme.
      # If it is not available, Orion is very similar to Breeze.
      ++ lib.optional (!(lib.hasAttr "breeze-gtk" kde5)) pkgs.orion

      # Install Breeze icons if available
      ++ lib.optional (lib.hasAttr "breeze-icons" kde5) kde5.breeze-icons

      # Install activity manager if available
      ++ lib.optional (lib.hasAttr "kactivitymanagerd" kde5) kde5.kactivitymanagerd

      # frameworkintegration was split with plasma-integration in Plasma 5.6
      ++ lib.optional (lib.hasAttr "plasma-integration" kde5) kde5.plasma-integration

      # Optional hardware support features
      ++ lib.optional config.hardware.bluetooth.enable kde5.bluedevil
      ++ lib.optional config.networking.networkmanager.enable kde5.plasma-nm
      ++ lib.optional config.hardware.pulseaudio.enable kde5.plasma-pa
      ++ lib.optional config.powerManagement.enable kde5.powerdevil
      ++ lib.optional config.services.colord.enable kde5.colord-kde
      ++ lib.optionals config.services.samba.enable [ kde5.kdenetwork-filesharing pkgs.samba ];

    environment.pathsToLink = [ "/share" ];

    environment.etc = singleton {
      source = "${pkgs.xkeyboard_config}/etc/X11/xkb";
      target = "X11/xkb";
    };

    # Enable GTK applications to load SVG icons
    environment.variables =
      {
        GST_PLUGIN_SYSTEM_PATH_1_0 =
          lib.makeSearchPath "/lib/gstreamer-1.0"
          (builtins.map (pkg: pkg.out) (with pkgs.gst_all_1; [
            gstreamer
            gst-plugins-base
            gst-plugins-good
            gst-plugins-ugly
            gst-plugins-bad
            gst-libav # for mp3 playback
          ]));
      }
      // (if (lib.hasAttr "breeze-icons" kde5)
          then { GDK_PIXBUF_MODULE_FILE = "${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"; }
          else { });

    fonts.fonts = [ (kde5.oxygen-fonts or pkgs.noto-fonts) ];

    programs.ssh.askPassword = "${kde5.ksshaskpass.out}/bin/ksshaskpass";

    # Enable helpful DBus services.
    services.udisks2.enable = true;
    services.upower.enable = config.powerManagement.enable;

    # Extra UDEV rules used by Solid
    services.udev.packages = [
      pkgs.libmtp
      pkgs.media-player-info
    ];

    services.xserver.displayManager.sddm = {
      theme = "breeze";
      themes = [
        kde5.extra-cmake-modules # for the setup-hook
        kde5.plasma-workspace
        kde5.breeze-icons
        (kde5.oxygen-icons or kde5.oxygen-icons5)
      ];
    };

    security.pam.services.kde = { allowNullPassword = true; };

  };

}
