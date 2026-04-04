{ pkgs }:

pkgs.runCommand "test-app-web" { } ''
  mkdir -p $out
  cp ${./index.html} $out/index.html
  cp ${./page2.html} $out/page2.html
''
