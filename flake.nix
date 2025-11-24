{
  description = "3D Slicer (binary) wrapped for Nix (Linux)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
  let
    systems = [ "x86_64-linux" ];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        f system (import nixpkgs { inherit system; })
      );
  in {
    packages = forAllSystems (system: pkgs:
      let
        slicer = pkgs.stdenvNoCC.mkDerivation {
          pname = "slicer";
          version = "5.10.0";

          src = pkgs.fetchurl {
            url = "https://download.slicer.org/bitstream/6911d062ac7b1c95e7935259";
            sha512 = "2ea56b6f0c027fa73c832b23c34948e69b1b5124edf337a35f6a062f5cb78e7feb792c11bc02a4986f26e458ddfd954b00255953018bf6cc7d73834aba9f0267";
          };

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];

          buildInputs = with pkgs; [
            stdenv.cc.cc.lib
            zlib
            bzip2
            curl
            libarchive
            fftw
            libffi
            openssl
            hwloc
            icu
            xorg.libX11
            xorg.libXext
            xorg.libXrender
            xorg.libXfixes
            xorg.libXcursor
            libGL
            libGLU
          ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/opt $out/bin
            tar -xzf $src -C $out/opt

            slicerDir=$(echo $out/opt/Slicer-*-linux-amd64)

            ln -s "$slicerDir/Slicer" "$out/bin/slicer"
            runHook postInstall
          '';
        };
      in {
        default = slicer;
        slicer = slicer;
      }
    );

    apps = forAllSystems (system: pkgs: {
      default = {
        type = "app";
        program = "${self.packages.${system}.slicer}/bin/slicer";
      };
    });
  };
}
