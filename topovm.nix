{ config, pkgs, ... }:

{
  imports = [
    ./topo-desktop.nix
  ];

  system.stateVersion = "25.05";

  # Español por defecto (importante para el abuelo)
  i18n.defaultLocale = "es_PA.UTF-8";
  i18n.supportedLocales = [
    "es_PA.UTF-8/UTF-8"
    "es_ES.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];
  console.keyMap = "es";

  # Entorno de escritorio ligero (RAM limitada en la laptop: 7.2GB)
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.desktopManager.xfce.enableXfwm = true;
  services.displayManager.defaultSession = "xfce";
  # Driver de video de VirtualBox (auto-resize en vivo, no solo al reiniciar)
  services.xserver.videoDrivers = [ "virtualbox" ];

  # Herramientas de topografía
  environment.systemPackages = with pkgs; [
    qgis
    librecad
    freecad
    qcad
    grass
    cloudcompare
    inkscape
    gimp
    # Visores / utilidades CAD y GIS
    gdal
    proj
    # Lectura de planos
    mupdf
    # Utilidades
    file
    unzip
    p7zip
    xarchiver
    gedit
    xfce.xfce4-terminal
  ];

  # Usuario para el abuelo
  users.users.topografia = {
    isNormalUser = true;
    description = "Topografia";
    extraGroups = [ "wheel" "vboxsf" ];
    password = "topografia";
  };

  # Contraseña de root por si cae a emergencia
  users.users.root.initialPassword = "topografia";

  # VirtualBox Guest Additions (sin carpeta compartida hardcodeada:
  # cada usuario configura su carpeta compartida desde la GUI de VirtualBox)
  virtualisation.virtualbox.guest.enable = true;

  # Autologin al escritorio
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "topografia";
}
