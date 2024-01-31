{ lib
, rustPlatform
}:

rustPlatform.buildRustPackage {
  inherit ((builtins.fromTOML (builtins.readFile ./Cargo.toml)).package) name;
  src = lib.cleanSource ./.;
  cargoLock = {
    lockFile = ./Cargo.lock;
  };
  doCheck = false;
}
