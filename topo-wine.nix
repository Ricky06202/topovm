# Módulo: programas del abuelo vía Wine
# - Leica Survey Office        (instalador InstallShield, 12MB)
# - PC Simulator CS Viva       (simulador Leica, requiere .NET 2.0, 160MB)
# - Carlson Sight Survey 2016  (instalador, 208MB)
#
# Estrategia:
# - Wine estable (wineWow64Packages.stable) en el sistema.
# - Los instaladores NO están en el repo git (son 380MB y no caben en GitHub).
#   Se empaquetan en la imagen desde el DISCO DEL ANFITRIÓN (carpeta de
#   Descargas de Ricky) durante el BUILD del .ova — quedan en /nix/store de la VM.
#   Ajusta LOCAL_INSTALLERS abajo si la carpeta cambia.
# - Cada programa tiene un launcher que: la 1ª vez inicia el wineprefix
#   (wineboot -i) y después corre el instalador con Wine (el abuelo responde
#   el wizard). Los launchers se exponen en el escritorio como .desktop.
# - Las 2 carpetas de manuales se copian al escritorio (estos SÍ van en git).
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

  # Ruta LOCAL (anfitrión) donde están los instaladores de Windows.
  # Solo existe/importa al BUILD en la máquina de Ricky (no en el repo git).
  localInstallers = "/home/ricky/Descargas/Programas de equipos";

  wine = pkgs.wineWow64Packages.stable;

  # ---------- Empaquetar los instaladores desde el host ----------
  # Se importan al Nix store como fuentes del build (quedan en /nix/store de la
  # VM). NOTA:
  #  - Solo funcionan en el equipo donde existe LOCAL_INSTALLERS (Ricky).
  #  - En modo puro (sin --impure) Nix bloquea el path externo → usamos un
  #    placeholder para que `nix flake check` puro no truene. El BUILD real
  #    del .ova SIEMPRE se hace con: nix build --impure .#virtualbox
  importLocal = tryArg:
    if builtins.pathExists tryArg
    then builtins.path { path = tryArg; name = "topo-instaladores-local"; }
    else builtins.path { path = ./placeholder; name = "topo-instaladores-empty"; };

  base = importLocal localInstallers;
  leicaSrc   = "${base}/Instalador Leica Survey Office";
  csVivaSrc  = "${base}/PC Simulator CS";
  carlsonSrc = "${base}/Carlson.Simplicity.Sight.Survey.2016.v3.0.0";

  installersStore = pkgs.runCommand "topo-installers" { } ''
    mkdir -p $out
    # Si el source no existe (build puro / otra máquina), no frustrar el build:
    # dejamos un aviso y el launcher avisará al ejecutarlo.
    cp -r "${leicaSrc}"   "$out/Instalador Leica Survey Office" 2>/dev/null || true
    cp -r "${csVivaSrc}"  "$out/PC Simulator CS"                2>/dev/null || true
    cp -r "${carlsonSrc}" "$out/Carlson.Simplicity.Sight.Survey.2016.v3.0.0" 2>/dev/null || true
    touch $out/instaladores-completos 2>/dev/null || true
  '';

  # Launcher de un instalador concreto dentro del wineprefix.
  # exe es la ruta del .exe RELATIVA a ${instDir}.
  mkInstallerRunner = pname: exe: pkgs.writeShellScriptBin "topo-install-${pname}" ''
    set -e
    export WINEPREFIX="${prefix}"
    export WINEDEBUG=-all
    if [ ! -f "$WINEPREFIX/.wine-initialized" ]; then
      mkdir -p "$WINEPREFIX"
      "${wine}/bin/wineboot" -i 2>/dev/null || true
      touch "$WINEPREFIX/.wine-initialized"
      echo "Wine prefix preparado."
    fi
    cd "${installersStore}"
    exec "${wine}/bin/wine" "${exe}"
  '';

  winecfgRunner = pkgs.writeShellScriptBin "topo-winecfg" ''
    export WINEPREFIX="${prefix}"
    export WINEDEBUG=-all
    exec "${wine}/bin/winecfg"
  '';

  # Lista de accesos al escritorio.
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
    mkdir -p "${prefix}"
    chown -R topografia:users "${prefix}" 2>/dev/null || true
  '';

  system.activationScripts.topoDesktopWine = lib.mkAfter ''
    mkdir -p "${desktop}"
    # Manuales (copiados desde el store: el store es inmutable)
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
