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
            url = "https://slicer-packages.kitware.com/api/v1/item/6911b598ac7b1c95e7934427/download";
            sha512 = "2ea56b6f0c027fa73c832b23c34948e69b1b5124edf337a35f6a062f5cb78e7feb792c11bc02a4986f26e458ddfd954b00255953018bf6cc7d73834aba9f0267";
          };

          nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
          autoPatchelfIgnoreMissingDeps = [ "libhwloc.so.5" ];

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
            nspr
            nss
            libxcrypt-legacy
            fontconfig
            freetype
            glib
            alsa-lib
            libpulseaudio
            cups
            postgresql
            unixODBC
            xorg.libX11
            xorg.libXext
            xorg.libXrender
            xorg.libXfixes
            xorg.libXcursor
            xorg.libXcomposite
            xorg.libXdamage
            xorg.libXrandr
            xorg.libXi
            xorg.libXtst
            xorg.libSM
            xorg.libICE
            xorg.libxcb
            xorg.xcbutil
            xorg.xcbutilimage
            xorg.xcbutilkeysyms
            xorg.xcbutilrenderutil
            xorg.xcbutilwm
            libGL
            libGLU
            libxkbcommon
          ];

          dontConfigure = true;
          dontBuild = true;
          dontUnpack = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out/opt $out/bin
            tar -xzf $src -C $out/opt

            slicerDir=$(echo $out/opt/Slicer-*-linux-amd64)

            # Provide compat libhwloc name expected by bundled TBB
            hwlocLib=$(echo ${pkgs.hwloc}/lib/libhwloc.so.*)
            if [ -f "$hwlocLib" ] && [ ! -e "$slicerDir/lib/libhwloc.so.5" ]; then
              ln -s "$hwlocLib" "$slicerDir/lib/libhwloc.so.5"
            fi

            # Wrapper to keep writable paths outside the Nix store and force xcb (wayland plugin is absent)
            makeWrapper "$slicerDir/Slicer" "$out/bin/slicer" \
              --set QT_QPA_PLATFORM xcb \
              --set SLICER_HOME "''${XDG_DATA_HOME:-\\$HOME/.local/share}/Slicer-5.10" \
              --set SLICER_EXTENSIONS_DIR "''${XDG_DATA_HOME:-\\$HOME/.local/share}/Slicer-5.10/Extensions" \
              --set SLICER_DICOM_DATABASE_DIR "''${XDG_DATA_HOME:-\\$HOME/.local/share}/SlicerDICOMDatabase" \
              --run 'mkdir -p "$SLICER_HOME" "$SLICER_EXTENSIONS_DIR" "$SLICER_DICOM_DATABASE_DIR"'
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
