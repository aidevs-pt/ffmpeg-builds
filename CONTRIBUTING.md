# Contributing

Thank you for helping improve these FFmpeg builds. Bug reports, fixes and ideas are all welcome.
You can write in English, Spanish or Portuguese.

## Before you start

- **Found a security problem?** Don't open an issue. Follow [SECURITY.md](SECURITY.md).
- **Bugs** go to this repository's issues, one per problem. Say which download and platform you
  used and include the command that failed.
- **Problems in FFmpeg itself,** such as a filter that misbehaves in every build, belong with
  the [FFmpeg project](https://ffmpeg.org/bugreports.html).
- **For anything larger than a small fix,** such as adding a library, open an issue first so we
  can agree on the approach. Every library must keep the builds small and redistributable.
- Everyone taking part follows our [Code of Conduct](CODE_OF_CONDUCT.md).

## Build and test

```sh
./fetch-sources.sh
./build.sh linux-x64 out/linux-x64
./smoke-test.sh out/linux-x64
```

The README lists the tools each platform needs. CI builds and tests every target on each pull
request.

## Guidelines

- **Pin every source** in `sources.txt` with its SHA-256.
- **Small, focused commits** with [Conventional Commits](https://www.conventionalcommits.org/)
  messages, such as `fix(windows): link libass statically`.
- **Extend the smoke test** when you add a feature others rely on.
- **Never commit credentials, binaries or build output.**

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make your change, with tests and documentation.
3. Open a pull request and fill in the template. CI must pass.
4. The first time you contribute, a bot asks you to sign the
   [Contributor License Agreement](CLA.md) by replying with a comment.
5. A maintainer reviews the change. We squash-merge, so the pull request title becomes the commit
   message.

## License

The build scripts are licensed under the [GNU Affero General Public License v3.0](LICENSE) and
owned by DEVS.AI UNIPESSOAL LDA. The [CLA](CLA.md) lets DEVS AI distribute your contribution under
this license and under other terms in the future; you keep the copyright to your work. The
binaries are GPL-2.0-or-later, as the README explains.
