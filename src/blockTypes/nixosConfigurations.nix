{
  nixpkgs,
  root,
}: let
  inherit
    (root)
    mkCommand
    ;

  l = nixpkgs.lib // builtins;

  privilegeElevationCommand = pkgs:
    pkgs.writeShellScript "elevate" ''
      HOSTVERSION="$(systemctl --version | head -n1 | cut -d' ' -f2)"

      if [ "$HOSTVERSION" -ge "256" ]; then
          run0 --setenv=PATH="$PATH" "$@"
      else
          sudo "$@"
      fi
    '';

  /*
  Use the nixosConfigurations Blocktype for
  final definitions of your NixOS hosts.
  */
  nixosConfigurations = {
    name = "nixosConfigurations";
    type = "nixosConfiguration";
    # nixosGenerator's actions?
    # microvm action?
    actions = {
      currentSystem,
      fragment,
      fragmentRelPath,
      target,
      inputs,
    }: let
      pkgs = inputs.nixpkgs.${currentSystem};
      getString = o: (l.elemAt (l.splitString ["/"] fragmentRelPath) o);
      host = (getString 0) + "-" + (getString 2);
      dc = getString 1;
      bin = ''
        bin=$(nix build .#${dc}.${host}.system --no-link --print-out-paths)/sw/bin
        export PATH=$bin:$PATH
      '';
    in (
      l.attrsets.mapAttrsToList
      (
        name: description: (mkCommand currentSystem {
          inherit name description;
          command =
            bin
            + l.optionalString (l.elem name [
              "switch"
              "boot"
              "test"
              "dry-activate"
            ]) (privilegeElevationCommand pkgs)
            + " nixos-rebuild ${name} --flake ${self} $@";
        })
      )
      {
        switch = "Activate & set as default boot.";
        boot = "Set default boot, run old config.";
        test = "Build & activate, no boot entry.";
        build = "Build new config.";
        dry-build = "Simulate build, show changes.";
        dry-activate = "Simulate activation, show changes.";
        edit = "Edit configuration with default editor.";
        repl = "Opens the configuration in nix repl.";
        build-vm = "Build script for NixOS virtual machine.";
        build-vm-with-bootloader = "Build script with host-like bootloader.";
        list-generations = "List system build generations.";
      }
    );
  };
in
  nixosConfigurations
