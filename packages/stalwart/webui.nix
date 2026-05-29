{
  lib,
  git,
  zip,
  fetchFromGitHub,
  nix-update-script,
  buildNpmPackage,
}:
buildNpmPackage (finalAttrs: {
  pname = "stalwart-webui";
  version = "1.0.4";
  nativeBuildInputs = [
    git
    zip
  ];
  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "webui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-V1g5lzkmO2NadRETwmp7ijEuzG3n83uO+6O1wdlF8G8=";
  };

  npmDepsHash = "sha256-XusIkv2lSwO/FXy+QsLAtcrSwN28SUa07/kj39Mr+u0=";
  npmPackFlags = [ "--ignore-scripts" ];
  NODE_OPTIONS = [ "--openssl-legacy-provider" ];

  installPhase = ''
    runHook preInstall 

    zip -r $out ./dist 

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "The new Stalwart Webui";
    homepage = "https://stalw.art";
    license = lib.licenses.agpl3Only;
  };
})
