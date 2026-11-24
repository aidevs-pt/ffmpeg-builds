# FFmpeg builds

Small static builds of FFmpeg and ffprobe that applications can ship with. Each build has
what video editing needs, and every source it uses is pinned and published with the release.

| Download | Runs on |
| --- | --- |
| `ffmpeg-<version>-linux-x64.zip` | Linux x64 with glibc 2.35 or newer (Ubuntu 22.04, Debian 12, Fedora 36 and later) |
| `ffmpeg-<version>-windows-x64.zip` | Windows 10 and 11, x64 |
| `ffmpeg-<version>-macos-universal.zip` | macOS 11 or newer, Apple silicon and Intel |
| `ffmpeg-<version>-macos-arm64.zip`, `-macos-x64.zip` | The same macOS builds, one architecture each |

Get them from [Releases](https://github.com/aidevs-pt/ffmpeg-builds/releases). `SHA256SUMS` in each
release lists the checksum of every file.

## What's included

- **Encoders:** H.264 (x264), AAC, MP3 (LAME), PNG and PCM.
- **Decoders:** everything FFmpeg decodes natively, including H.264, HEVC, VP9, ProRes and Opus,
  plus AV1 through dav1d.
- **Text:** subtitles and drawn text through libass, FreeType, HarfBuzz and FriBidi. libass
  finds system fonts through fontconfig on Linux, CoreText on macOS and DirectWrite on Windows.
- **Hardware:** VideoToolbox and AudioToolbox on macOS.

Network protocols, `ffplay` and anything that would make the build non-redistributable are left
out. Each archive's `BUILD.txt` lists the exact sources and FFmpeg configuration.

## Licenses

The binaries are distributed under the **GNU GPL, version 2 or later**, because they include x264
and FFmpeg's GPL components. Each archive has a `licenses/` folder with the license of every
library inside it. Every release also attaches the exact source archive of each component,
with `build.sh`, so you can rebuild the same binaries.

An application that only runs these binaries as separate programs can use any license. Check
the GPL's terms before linking FFmpeg into your own code.

The build scripts in this repository are licensed under the
[GNU Affero General Public License v3.0](LICENSE).

## Build it yourself

```sh
./fetch-sources.sh                      # downloads and verifies every source
./build.sh linux-x64 out/linux-x64      # or macos-arm64, macos-x64, windows-x64
./smoke-test.sh out/linux-x64           # encodes, probes and burns in text
```

Linux needs a C and C++ compiler, `make`, `nasm`, `gperf`, `pkg-config`, `meson` and `ninja`.
`windows-x64` cross-compiles from Linux with `mingw-w64`. macOS needs the Xcode command line
tools, `nasm` and `pkgconf`. [.github/workflows/build.yml](.github/workflows/build.yml) builds
every target. Pushing a tag such as `v9.1-1` (the FFmpeg version and a build number) publishes a
release.

To update a library, change its line in `sources.txt` and replace the SHA-256 with the
checksum of the new archive.

## Contributing

Issues and pull requests are welcome. Please describe the platform and the command that failed.

---

Maintained by [DEVS AI Unipessoal LDA](https://aidevs.pt). Need custom AI solutions? Visit
[aidevs.pt](https://aidevs.pt).
