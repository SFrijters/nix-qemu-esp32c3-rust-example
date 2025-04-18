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

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes."rust-mqtt-0.3.0" = "sha256-jFXwQ0yG+t9mFam1XqH22kTNUVpsofpic0Ph6zzW8tg=";
  };

  SSID = builtins.getEnv "SSID";
  PASSWORD = builtins.getEnv "PASSWORD";
  MQTT_HOST = builtins.getEnv "MQTT_HOST";
  PUBLISH_TOPIC = builtins.getEnv "PUBLISH_TOPIC";
  RECEIVE_TOPIC = builtins.getEnv "RECEIVE_TOPIC";

  doCheck = false;
}
