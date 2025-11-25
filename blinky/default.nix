{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  inherit ((builtins.fromTOML (lib.readFile ./Cargo.toml)).package) name;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.lock
      ./Cargo.toml
      ./src
      ./.cargo
    ];
  };

  # Work around https://github.com/NixOS/nixpkgs/pull/435278 - RUSTFLAGS is always set now and overrides .cargo/config.toml.
  # TODO: Keep an eye on
  # https://github.com/NixOS/nixpkgs/pull/464707
  # https://github.com/NixOS/nixpkgs/pull/464992
  # and possibly revert or adjust to the new status quo in nixpkgs.
  RUSTFLAGS = (builtins.fromTOML (builtins.readFile ./.cargo/config.toml)).build.rustflags;

  cargoLock.lockFile = ./Cargo.lock;

  doCheck = false;

  meta.license = lib.licenses.mit;
}
