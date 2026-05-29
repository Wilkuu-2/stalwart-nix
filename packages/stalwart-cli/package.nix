{
  lib,
  rustPlatform,
  versionCheckHook,
  fetchFromGitHub,
  openssl,
  pkg-config,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "stalwart-cli";
  version = "1.0.7";
  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-34paJniHaVTLLxW6hRNmpANgj3/6aQkYhhW3Pg0dEek=";
  };

  cargoHash = "sha256-c3wAT1I8Ym8UaIG26qv3tih++y5GWqfKuNzCuU7yUZE=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  env.OPENSSL_NO_VENDOR = true;

  cargoBuildFlags = [
    "--package"
    "stalwart-cli"
  ];
  cargoTestFlags = [
    "--package"
    "stalwart-cli"
  ];

  checkFlags = lib.forEach [
    #called `Result::unwrap()` on an `Err` value: Network(reqwest::Error { kind: Builder, source: General("No CA certificates were loaded from the system") })
    # TODO: If I weren't just going at it crazy style, I'd probably manage to fix this.
    "commands::snapshot::tests::emit_create_flushes_sink_around_reporter_calls"
    "commands::snapshot::tests::emit_create_flushes_sink_on_empty_shard"
    "commands::snapshot::tests::emit_create_omits_deferred_field_and_emits_followup_update"
  ] (test: "--skip=${test}");

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Stalwart Mail Server CLI";
    mainProgram = "stalwart-cli";
    homepage = "https://github.com/stalwartlabs/cli";
    changelog = "https://github.com/stalwartlabs/cli/blob/main/CHANGELOG.md";
    license = lib.licenses.agpl3Only;
    # maintainers = with lib.maintainers; [
    #   giomf
    # ];
  };
})
