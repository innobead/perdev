{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, dbus }:

stdenvNoCC.mkDerivation rec {
  pname = "bzr";
  version = "0.8.1";

  src = fetchurl {
    url = "https://github.com/randomparity/bzr/releases/download/v${version}/bzr-v${version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-fMMlLJjJtjhmivmpFi72v9Z+Y5wJ45zmDOqu4YNppQ8=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ dbus ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bzr "$out/bin/bzr"
    install -d "$out/share/man/man1"
    install -m644 man/man1/*.1 "$out/share/man/man1/"

    runHook postInstall
  '';

  meta = {
    description = "Bugzilla CLI inspired by GitHub's gh";
    homepage = "https://github.com/randomparity/bzr";
    license = lib.licenses.mit;
    mainProgram = "bzr";
    platforms = [ "x86_64-linux" ];
  };
}
