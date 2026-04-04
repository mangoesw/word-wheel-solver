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

        compileroptions = "-std=c++20 -Wall -Wextra -Wpedantic -Werror";

        deps = "dbus-1 libpipewire-0.3 wayland-client";
        cflags = "$(pkg-config --cflags ${deps} | sed -E 's/(^| )-I/\\1 -isystem/g')";
        libs = "$(pkg-config --libs ${deps})";

        appName = "solveww";
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = appName;
          version = "0.1.0";
          src = lib.cleanSource ./.;

          nativeBuildInputs = with pkgs; [
            pkg-config
            wayland-scanner
          ];
          
          buildInputs = with pkgs; [
            dbus
            pipewire
            wayland
            wayland-protocols
          ];

          buildPhase = ''
            runHook preBuild

            mapfile -t CPP_FILES < <(find . -type f -name '*.cpp' | sort)

            if [ "''${#CPP_FILES[@]}" -eq 0 ]; then
              echo "No .cpp files found."
              exit 1
            fi

            printf '  %s\n' "''${CPP_FILES[@]}"

            $CXX \
              ${compileroptions} \
              "''${CPP_FILES[@]}" \
              ${cflags} ${libs} \
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
          ];

          inputsFrom = [ self.packages.${system}.default ];

          shellHook = ''
            PS1='\[\e[38;5;32;1m\][flake]\$ \[\e[0m\]'
            pkg-config --list-all
            echo ${cflags} | tr ' ' '\n' > "compile_flags.txt"
            echo ${compileroptions} | tr ' ' '\n' >> "compile_flags.txt"
          '';
        };
      });
}
