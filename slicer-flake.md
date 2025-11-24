Kurzfassung: Bauen aus Source mit Nix ist bei Slicer derzeit richtig mühsam (CMake lädt Sachen aus dem Netz, was Nix nicht mag). ([3D Slicer Community][1])
Ich zeige dir daher einen **Flake, der das offizielle Linux-Binary tar.gz “einwrappt”** – das ist robust genug für den Alltag und schnell gemacht.

---

## 1. Download-URL & Checksum besorgen

1. Geh auf die Slicer-Downloadseite (Linux): ([3D Slicer][2])
   → `https://download.slicer.org/`
2. Klick auf **Linux → Stable 5.10.0**.
3. Wenn der Download startet, kopier dir im Browser die **direkte URL** der Datei.

   * Die Datei heißt laut Doku z.B. so ähnlich wie
     `Slicer-5.10.0-linux-amd64.tar.gz` ([3D Slicer][2])
   * Die URL ist typischerweise etwas wie
     `https://download.slicer.org/bitstream/<irgendeine-ID>`
4. Auf der selben Seite steht auch der **SHA512-Hash für Linux**, aktuell: ([3D Slicer][2])

   ```text
   2ea56b6f0c027fa73c832b23c34948e69b1b5124edf337a35f6a062f5cb78e7f
   eb792c11bc02a4986f26e458ddfd954b00255953018bf6cc7d73834aba9f0267
   ```

   (Ohne Zeilenumbruch in Nix einfügen.)

---

## 2. Minimaler Flake, der Slicer wrapped

Lege ein neues Verzeichnis an, z.B.:

```bash
mkdir slicer-flake
cd slicer-flake
```

Erstelle darin eine Datei `flake.nix` mit etwa folgendem Inhalt:

```nix
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

          # 1) Hier deine echte Download-URL eintragen
          src = pkgs.fetchurl {
            url = "https://download.slicer.org/bitstream/DEINE_ID_HIER"; # <-- anpassen
            sha512 = "2ea56b6f0c027fa73c832b23c34948e69b1b5124edf337a35f6a062f5cb78e7feb792c11bc02a4986f26e458ddfd954b00255953018bf6cc7d73834aba9f0267";
          };

          # Patchelf versucht automatisch fehlende libs über buildInputs zu finden
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

          # Wir entpacken den tarball einfach nach $out/opt
          installPhase = ''
            runHook preInstall
            mkdir -p $out/opt $out/bin
            tar -xzf $src -C $out/opt

            # Verzeichnis heißt typischerweise Slicer-5.10.0-linux-amd64
            slicerDir=$(echo $out/opt/Slicer-*-linux-amd64)

            # Einfaches CLI-Entry "slicer"
            ln -s "$slicerDir/Slicer" "$out/bin/slicer"
            runHook postInstall
          '';
        };
      in {
        default = slicer;
        slicer = slicer;
      }
    );

    # nix run . startet direkt Slicer
    apps = forAllSystems (system: pkgs: {
      default = {
        type = "app";
        program = "${self.packages.${system}.slicer}/bin/slicer";
      };
    });
  };
}
```

**Was du anpassen musst:**

* `url = "https://download.slicer.org/bitstream/DEINE_ID_HIER";`
  → Ersetze durch deine echte Linux-Download-URL.
* Falls der Name des entpackten Ordners anders ist als `Slicer-*-linux-amd64`, musst du im `installPhase` ggf. den `slicerDir`-Globbing anpassen.

---

## 3. Slicer mit Flakes benutzen

### 3.1. Lokal im Verzeichnis laufen lassen

Im `slicer-flake` Verzeichnis:

```bash
# Einmalig die Flake auswerten & bauen, dann sofort starten
nix run .
# oder explizit
nix run .#slicer
```

### 3.2. Als User-“Installation” (nix profile)

```bash
# Im Flake-Verzeichnis:
nix profile install .#slicer

# Danach ist es dauerhaft im Profil:
which slicer    # sollte auf /nix/store/.../bin/slicer zeigen
slicer          # startet 3D Slicer
```

Später wieder entfernen:

```bash
nix profile list          # Profil-Index raussuchen
nix profile remove <index>
```

---

## 4. In deine NixOS-Systemflake integrieren

Wenn du eine NixOS-Konfiguration als Flake hast, kannst du deine Slicer-Flake als Input verwenden:

```nix
{
  description = "Mein NixOS mit Slicer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    slicer-flake.url = "path:/home/bjoern/git/slicer-flake";
    # oder: "github:deinUser/slicer-flake";
  };

  outputs = { self, nixpkgs, slicer-flake, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    nixosConfigurations.cps-nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        {
          environment.systemPackages = [
            slicer-flake.packages.${system}.slicer
          ];
        }
      ];
    };
  };
}
```

Dann wie gewohnt:

```bash
sudo nixos-rebuild switch --flake .#cps-nixos
slicer
```

---

## 5. Hinweise / Stolpersteine

* **Build aus Source** unter Nix ist aktuell schwierig, weil Slicer-CMake beim Konfigurieren noch Dinge aus dem Netz zieht (Extensions, Third-Party Libs, …). ([3D Slicer Community][1])
  → Für reproduzierbare Nix-Builds müsste man den ganzen Superbuild erheblich umbauen oder patchen.
* Mit dem oben gezeigten **Binary-Wrapper** umgehst du das Problem und hast trotzdem eine saubere Nix-Integration (Store-Pfad, `nix run`, `nix profile`, Flake-Inputs, …).
* Wenn Slicer beim Start über fehlende Libraries meckert, kannst du einfach weitere Pakete in `buildInputs` ergänzen. (Orientier dich ggf. an der Dependency-Liste der Arch-AUR-PKGBUILD für `3dslicer` ([AUR][3]))

---

Wenn du magst, können wir im nächsten Schritt:

* die `buildInputs` anhand deiner konkreten Fehlermeldungen feinjustieren, oder
* eine zweite Variante bauen, die Slicer in einer FHS-User-Env (`buildFHSEnv`) laufen lässt, falls es ohne zu viel Gefrickel nicht startet.

[1]: https://discourse.slicer.org/t/offline-build-support-for-packaging/37616 "Offline build support for packaging - Support - 3D Slicer Community"
[2]: https://download.slicer.org/ "Download 3D Slicer | 3D Slicer"
[3]: https://aur.archlinux.org/packages/3dslicer?O=40 "AUR (en) - 3dslicer"
