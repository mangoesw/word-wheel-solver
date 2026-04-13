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

        WAYLAND_PROTOCOLS_DIR = "$(pkg-config wayland-protocols --variable=pkgdatadir)";
        XDG_SHELL_PROTOCOL = "${WAYLAND_PROTOCOLS_DIR}/stable/xdg-shell/xdg-shell.xml";
        xdg_h = "wayland-scanner client-header ${XDG_SHELL_PROTOCOL} xdg-shell-client-protocol.h";
        xdg_c = "wayland-scanner private-code ${XDG_SHELL_PROTOCOL} xdg-shell-protocol.c";

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

            ${xdg_c}
            ${xdg_h}

            $CXX -c ${compileroptions} -w xdg-shell-protocol.c

            mapfile -t CPP_FILES < <(find . -type f -name '*.cpp' | sort)

            if [ "''${#CPP_FILES[@]}" -eq 0 ]; then
              echo "No source files found."
              exit 1
            fi

            printf '  %s\n' "''${CPP_FILES[@]}"

            $CXX \
              -c \
              ${compileroptions} \
              "''${CPP_FILES[@]}" \
              ${cflags}

            mapfile -t O_FILES < <(find . -type f -name '*.o' | sort)
            $CXX \
              ${compileroptions} \
              "''${O_FILES[@]}" \
              ${libs} \
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
            ${xdg_h}
            PS1='\[\e[38;5;32;1m\][flake]\$ \[\e[0m\]'
            pkg-config --list-all
            echo ${cflags} | tr ' ' '\n' > "compile_flags.txt"
            echo ${compileroptions} | tr ' ' '\n' >> "compile_flags.txt"
          '';
        };
      });
}
