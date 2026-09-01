{ config, pkgs, lib, ... }:

let
  desktopDir = "/home/topografia/Desktop";
  # nombre -> { exec; icon; }
  apps = {
    "QGIS" = { exec = "qgis"; icon = "qgis"; };
    "QCAD" = { exec = "qcad"; icon = "qcad"; };
    "LibreCAD" = { exec = "librecad"; icon = "librecad"; };
    "FreeCAD" = { exec = "freecad"; icon = "freecad"; };
    "GRASS GIS" = { exec = "grass"; icon = "grass"; };
    "CloudCompare" = { exec = "CloudCompare"; icon = "cloudcompare"; };
    "Wine Config" = { exec = "winecfg"; icon = "wine"; };
    "Terminal" = { exec = "xfce4-terminal"; icon = "utilities-terminal"; };
  };
in {
  system.activationScripts.topoDesktop = lib.mkAfter ''
    mkdir -p ${desktopDir}
    ${lib.concatStrings (lib.mapAttrsToList (name: a: ''
      cat > ${desktopDir}/${name}.desktop <<EOF
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=${name}
      Comment=Topografia
      Exec=${a.exec}
      Icon=${a.icon}
      Terminal=false
      Categories=Education;Geography;
      EOF
      chmod +x ${desktopDir}/${name}.desktop
      chown topografia:users ${desktopDir}/${name}.desktop
    '') apps)}
  '';
}
