{
  description = "VM NixOS portable con herramientas de topografía (QGIS, LibreCAD, FreeCAD) + programas del abuelo vía Wine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-generators, ... }: {

    # Imagen VirtualBox (.vdi) reproducible con nixos-generators
    packages.x86_64-linux.virtualbox = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [
        ./topovm.nix
        ./topo-wine.nix
      ];
      format = "virtualbox";
    };

    # ISO instalable/live (NO usa la fase QEMU que se cuelga)
    packages.x86_64-linux.iso = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [
        ./topovm.nix
        ./topo-wine.nix
      ];
      format = "iso";
    };

    packages.x86_64-linux.default = self.packages.x86_64-linux.virtualbox;

  };
}
