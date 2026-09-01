# Módulo: programas del abuelo vía Wine
# - Leica Survey Office        (instalador InstallShield, 12MB)
# - PC Simulator CS Viva       (simulador Leica, requiere .NET 2.0, 160MB)
# - Carlson Sight Survey 2016  (instalador, 208MB)
#
# Estrategia:
# - Wine estable (wineWow64Packages.stable) en el sistema.
# - Los instaladores se copian a /home/topografia/Instaladores en el build.
# - Cada programa tiene un launcher que: la 1ª vez inicia el wineprefix
#   (wineboot -i) y después corre el instalador con Wine (el abuelo responde
#   el wizard). Los launchers se exponen en el escritorio como .desktop.
# - Las 2 carpetas de manuales se copian al escritorio.
#
# wineprefix compartido: /home/topografia/.wine-topo
# Acceso manual (licencias, registro, instaladores):
#   export WINEPREFIX=/home/topografia/.wine-topo
#   winecfg                       # panel de configuración de Wine
#   thunar ~/.wine-topo/drive_c   # explorar los "discos" de Windows
#   ls ~/Instaladores             # los instaladores copiados

{ config, pkgs, lib, ... }:

let
  home    = "/home/topografia";
  desktop = "${home}/Desktop";
  prefix  = "${home}/.wine-topo";
  instDir = "${home}/Instaladores";

  wine = pkgs.wineWow64Packages.stable;

  # Launcher de un instalador concreto dentro del wineprefix.
  # winpath es la ruta del .exe relativa a ${instDir} (en formato Windows)
  mkInstallerRunner = pname: winpath: pkgs.writeShellScriptBin "topo-install-${pname}" ''
    set -e
    export WINEPREFIX="${prefix}"
    export WINEDEBUG=-all
    if [ ! -f "$WINEPREFIX/.wine-initialized" ]; then
      mkdir -p "$WINEPREFIX"
      "${wine}/bin/wineboot" -i 2>/dev/null || true
      touch "$WINEPREFIX/.wine-initialized"
      echo "Wine prefix preparado."
    fi
    cd "${instDir}"
    exec "${wine}/bin/wine" "${winpath}"
  '';

  winecfgRunner = pkgs.writeShellScriptBin "topo-winecfg" ''
    export WINEPREFIX="${prefix}"
    export WINEDEBUG=-all
    exec "${wine}/bin/winecfg"
  '';

  # Lista de accesos al escritorio.
  # El runner ya codifica la ruta del .exe (relativa a ${instDir}) y hace
  # `cd ${instDir}` antes, así los instaladores InstallShield leen sus .cab.
  launchers = [
    {
      pname     = "leica";
      label     = "Leica Survey Office";
      runner    = mkInstallerRunner "leica" "Instalador Leica Survey Office\\SETUP.EXE";
    }
    {
      pname     = "csviva";
      label     = "PC Simulator CS Viva";
      runner    = mkInstallerRunner "csviva" "PC Simulator CS\\Setup.exe";
    }
    {
      pname     = "carlson";
      label     = "Carlson Sight Survey 2016";
      runner    = mkInstallerRunner "carlson" "Carlson.Simplicity.Sight.Survey.2016.v3.0.0\\install\\SightSurvey2016.exe";
    }
  ];

in {
  environment.systemPackages = with pkgs; [
    wine
    winetricks
  ] ++ (map (l: l.runner) launchers) ++ [ winecfgRunner ];

  system.activationScripts.topoWine = lib.mkAfter ''
    mkdir -p "${instDir}" "${prefix}"
    cp -r ${./programs}/. "${instDir}"/
    chmod -R u+w "${instDir}"
    chown -R topografia:users "${instDir}" "${prefix}" 2>/dev/null || true
  '';

  system.activationScripts.topoDesktopWine = lib.mkAfter ''
    mkdir -p "${desktop}"
    # Manuales (copiados, no symlinks: el store es inmutable)
    cp -r ${./manuals}/"CARPETA DE DIGITAL" "${desktop}/" 2>/dev/null || true
    cp -r ${./manuals}/"Manual Simulador"   "${desktop}/" 2>/dev/null || true
    chown -R topografia:users "${desktop}/CARPETA DE DIGITAL" "${desktop}/Manual Simulador" 2>/dev/null || true
    chmod -R u+w "${desktop}/CARPETA DE DIGITAL" "${desktop}/Manual Simulador" 2>/dev/null || true

    ${lib.concatStrings (map (l: ''
      cat > "${desktop}/${l.label}.desktop" <<EOF
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=${l.label}
      Comment=Programa via Wine
      Exec=${l.runner}/bin/topo-install-${l.pname}
      Icon=wine
      Terminal=false
      Categories=Education;
      EOF
      chmod +x "${desktop}/${l.label}.desktop"
      chown topografia:users "${desktop}/${l.label}.desktop"
    '') launchers)}

    # Config de Wine (su binario difiere del esquema topo-install-*)
    cat > "${desktop}/Configuracion de Wine.desktop" <<EOF
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=Configuracion de Wine
    Comment=Panel de configuración de Wine
    Exec=${winecfgRunner}/bin/topo-winecfg
    Icon=wine
    Terminal=false
    Categories=Settings;
    EOF
    chmod +x "${desktop}/Configuracion de Wine.desktop"
    chown topografia:users "${desktop}/Configuracion de Wine.desktop"
  '';
}
