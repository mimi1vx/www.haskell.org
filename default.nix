{ compiler ? "ghc843"
, rev      ? "9f88b3cbeae8bc87294807ba6ce9252f9bb31ee0"
, pkgs     ?
    import (builtins.fetchTarball {
      url    = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
      }) {}
}:

let

  gitignore = pkgs.callPackage (pkgs.fetchFromGitHub {
      owner = "siers";
      repo = "nix-gitignore";
      rev = "4f2d85f2f1aa4c6bff2d9fcfd3caad443f35476e";
      sha256 = "1vzfi3i3fpl8wqs1yq95jzdi6cpaby80n8xwnwa8h2jvcw3j7kdz";
    }) {};

  builder = (pkgs.haskell.packages.${compiler}.developPackage {
      name = builtins.baseNameOf ./.;
      root = gitignore.gitignoreSource [
          "*.markdown"
          "*.md"
          "*.html"
          "templates/*"
          "css/*"
          "js/*"
          "img/*"
          ".git"
        ] ./.;
      modifier = drv: pkgs.haskell.lib.overrideCabal drv (attrs: {
        buildTools = with pkgs.haskell.packages.${compiler}; (attrs.buildTools or []) ++ [
          cabal-install
          ghcid
          hakyll
          pkgs.linkchecker
        ];
      });
    }).overrideAttrs (old: {
      shellHook = ''
        alias buildAndWatch="cabal configure && cabal build && ./dist/build/site/site clean && ./dist/build/site/site watch"
        echo ""
        echo "  Haskell.org Dev Shell"
        echo "    \`buildAndWatch\` to serve the site, and rebuild when files change."
        echo "    \`linkchecker\`, \`ghcid\` and \`cabal\` are provided in this environment."
        echo ""
      '';
    });

  built = pkgs.stdenv.mkDerivation {
    name = "haskell.org";
    src = gitignore.gitignoreSource [
      ".git"
      "*.cabal"
      "*.hs"
      ] ./.;
    buildInputs = [ builder pkgs.linkchecker ];
    LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
    LC_ALL = "en_US.UTF-8";
    installPhase = ''
      echo ""
      echo "  Building static site..."
      echo ""
      site build
      echo ""
      echo "  Checking for bad links..."
      echo ""
      linkchecker _site
      echo ""
      echo "  Copying static site to $out..."
      cp -r _site $out
      echo "  Build complete"
      echo ""
    '';
  };
in
  if pkgs.lib.inNixShell then builder
  else { inherit builder built; }
