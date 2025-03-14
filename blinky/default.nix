{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  inherit ((builtins.fromTOML (builtins.readFile ./Cargo.toml)).package) name;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.lock
      ./Cargo.toml
      ./src
      ./.cargo
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  doCheck = false;
}
