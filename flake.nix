{
  description = "word wheel solver project dev shell and build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        deps = with pkgs; [
          dbus
          pipewire
        ];

        appName = "solveww";
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = appName;
          version = "0.1.0";
          src = lib.cleanSource ./.;

          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = deps;

          buildPhase = ''
            runHook preBuild

            mapfile -t CPP_FILES < <(find . -type f -name '*.cpp' | sort)

            if [ "''${#CPP_FILES[@]}" -eq 0 ]; then
              echo "No .cpp files found."
              exit 1
            fi

            printf '  %s\n' "''${CPP_FILES[@]}"
            
            mapfile -t packages < <(pkg-config --list-all | awk '{print $1}')

            all_pkgconfig=""
            for pkg in "''${packages[@]}"; do
              pkgconfig=$(pkg-config --cflags --libs "$pkg")
              all_pkgconfig+="''${pkgconfig} "
            done
            
            all_pkgconfig="''${all_pkgconfig%" "}"
            echo "$all_pkgconfig"

            $CXX \
              -std=c++20 -Wall -Wextra -pedantic \
              "''${CPP_FILES[@]}" \
              $all_pkgconfig \
              -o ${appName}

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 ${appName} $out/bin/${appName}
            runHook postInstall
          '';

          meta = {
            description = "word wheel solver";
            mainProgram = appName;
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/${appName}";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gdb
            clang-tools
          ] ++ deps;
        };
      });
}
