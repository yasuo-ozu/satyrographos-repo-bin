# Satyrographos-repo-bin

This is binary version of [satyrographos-repo](https://github.com/na4zagin3/satyrographos-repo).
This repository provides some versions of `satysfi` and `satyrographos` packages with zero dependency.

Build status: [![Build](https://github.com/yasuo-ozu/satyrographos-repo-bin/actions/workflows/ci.yaml/badge.svg?branch=develop)](https://github.com/yasuo-ozu/satyrographos-repo-bin/actions/workflows/ci.yaml)
Install test: [![Install](https://github.com/yasuo-ozu/satyrographos-repo-bin/actions/workflows/install.yaml/badge.svg?branch=main)](https://github.com/yasuo-ozu/satyrographos-repo-bin/actions/workflows/install.yaml)

## How to use

This repository is useful when you are creating `opam local switch`.
Because the packages provided by this repository is zero-dependency, you don't have to install even `ocaml-base-compiler` in the switch.

```bash
# creating local switch (optional)
opam switch create . --empty
eval $(opam env)

# Add repositories
opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git
opam repository add satyrographos-repo-bin https://github.com/yasuo-ozu/satyrographos-repo-bin.git
opam repository add satyrographos-repo --rank 2 https://github.com/na4zagin3/satyrographos-repo.git

# List installable packages
opam list --all-versions --installable satysfi -o satyrographos

# install satysfi and satyrographos
opam install satysfi satyrographos
```

## Developing

This repository has several scripts and `satyrographos-repo` submodule in the `develop` branch.
To follow the upstream `satyrographos-repo`, we should sync these submodules.
Contributions are welcome.

