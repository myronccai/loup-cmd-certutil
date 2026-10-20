# loup-cmd-certutil

The hashing and encoding verbs of the Windows `certutil` command recreated
in [Loup](https://code-craft.ai/references/loup): `-hashfile` with MD5,
SHA-1, SHA-256, SHA-384 and SHA-512 written in pure Loup, and base64 and
hex conversion with certutil's framing, messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It shows the hash
algorithms implemented with Loup's 64-bit `int` (the Lite edition has no
crypto library), and verb dispatch (the template's dispatcher, kept). It
carries the shared Windows code in [`source/win/`](source/win/), copied
from [loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                                   # native binary: build/certutil
make ci                                      # check, unit tests, build, end-to-end tests
make run ARGS="-hashfile README.md SHA256"   # run from source with loup run
```

```text
$ build/certutil -hashfile 'demo\note.txt'
SHA1 hash of demo\note.txt:
42e7381a0dbb54478a7ec743d54e195c737197d1
CertUtil: -hashfile command completed successfully.
$ build/certutil -hashfile 'demo\note.txt' SHA256
SHA256 hash of demo\note.txt:
e51fd5bae1bc6a1fd266049d6ac6acdbbd02f4a7f0f5619240b70d847f051e46
CertUtil: -hashfile command completed successfully.
$ build/certutil -hashfile 'demo\note.txt' md5
MD5 hash of demo\note.txt:
830c319052bd43cbe6b5cc8059f10292
CertUtil: -hashfile command completed successfully.
$ build/certutil -encode 'demo\note.txt' 'demo\note.b64'
Input Length = 17
Output Length = 82
CertUtil: -encode command completed successfully.
$ cat demo/note.b64
-----BEGIN CERTIFICATE-----
SGVsbG8sIGNlcnR1dGlsIQo=
-----END CERTIFICATE-----
$ build/certutil -decode 'demo\note.b64' 'demo\copy.txt'
Input Length = 82
Output Length = 17
CertUtil: -decode command completed successfully.
$ cat demo/copy.txt
Hello, certutil!
$ build/certutil -encodehex 'demo\note.txt' 'demo\note.hex'
Input Length = 17
Output Length = 133
CertUtil: -encodehex command completed successfully.
$ cat demo/note.hex
0000	48 65 6c 6c 6f 2c 20 63  65 72 74 75 74 69 6c 21   Hello, certutil!
0010	0a                                                 .
$ build/certutil -encode 'demo\note.txt' 'demo\note.b64'; echo "ERRORLEVEL $?"
CertUtil: -encode command FAILED: 0x80070050 (WIN32: 80 ERROR_FILE_EXISTS)
CertUtil: The file exists.
ERRORLEVEL 80
$ build/certutil -hashfile 'demo\missing.txt'; echo "ERRORLEVEL $?"
CertUtil: -hashfile command FAILED: 0x80070002 (WIN32: 2 ERROR_FILE_NOT_FOUND)
CertUtil: The system cannot find the file specified.
ERRORLEVEL 2
$ build/certutil -hashfile 'demo\note.txt' MD4; echo "ERRORLEVEL $?"
CertUtil: -hashfile command FAILED: 0x80090008 (-2146893816 NTE_BAD_ALGID)
CertUtil: Invalid algorithm specified.
ERRORLEVEL 8
$ build/certutil --version
certutil (loup-cmd-certutil) 0.1.0
```

(The files certutil writes end their lines with CR LF.)

```text
certutil [-f] [-v] -VERB ARGUMENTS
```

| Verb | Does |
|---|---|
| `-hashfile InFile [Algorithm]` | print the file's hash in lower-case hexadecimal; `MD5`, `SHA1` (default), `SHA256`, `SHA384`, `SHA512`, in any case |
| `-encode InFile OutFile` | write base64 in lines of 64 characters between `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----` |
| `-decode InFile OutFile` | write the bytes of base64 text, with any `-----BEGIN ...-----` frame or none; whitespace is ignored |
| `-encodehex InFile OutFile [Type]` | write a hex dump: `11` (default: offset, hex, text), `10` (offset, hex), `4` (hex), `5` (hex, text), `12` (raw hex); or base64: `0` (certificate frame), `1` (no frame), `3` (request frame), `9` (CRL frame) |
| `-decodehex InFile OutFile [Type]` | read such a dump back (hex types by default; a base64 type reads base64) |

| Option | |
|---|---|
| `-f` | overwrite an existing OutFile (without it: `ERROR_FILE_EXISTS`) |
| `-v` | accepted; changes nothing |
| `-?`, `-VERB -?` | a summary of the verbs, or of one verb |

Verbs and options start with `-` or `/`, in any case (`/HashFile`); `--`
ends option parsing. The conversion verbs print `Input Length = N` and
`Output Length = N` (bytes) before the success line.

Exit status (ERRORLEVEL): `0` on success; on failure certutil's HRESULT, a
negative 32-bit number, of which a Linux shell sees the low 8 bits:

| HRESULT | Message | Seen on Linux |
|---|---|---|
| `0x80070002 (WIN32: 2 ERROR_FILE_NOT_FOUND)` | The system cannot find the file specified. | 2 |
| `0x80070003 (WIN32: 3 ERROR_PATH_NOT_FOUND)` | The system cannot find the path specified. | 3 |
| `0x80070005 (WIN32: 5 ERROR_ACCESS_DENIED)` | Access is denied. (a directory) | 5 |
| `0x8007000d (WIN32: 13 ERROR_INVALID_DATA)` | The data is invalid. (not base64 or hex) | 13 |
| `0x80070050 (WIN32: 80 ERROR_FILE_EXISTS)` | The file exists. | 80 |
| `0x80070057 (WIN32: 87 ERROR_INVALID_PARAMETER)` | The parameter is incorrect. (arguments) | 87 |
| `0x80090008 (-2146893816 NTE_BAD_ALGID)` | Invalid algorithm specified. | 8 |

## How the hashes are computed

[`source/hash/`](source/hash/) implements RFC 1321 (MD5) and FIPS 180-4
(SHA-1, SHA-256, SHA-512, SHA-384) on `bytes` read whole from the file.
Loup's sized integers (`uint32`, `uint64`) throw on overflow, so every
word is a plain `int`, which is 64 bits and wraps:

- 32-bit words stay in 0..2^32-1 by masking with `0xFFFFFFFF` after each
  addition, rotation and complement (`x ^ 0xFFFFFFFF`).
- SHA-512's 64-bit words use the whole `int`: addition wraps like an
  unsigned 64-bit add, `>>` is made logical with a mask (`shr64`), and
  the constants above 2^63 are built from 32-bit halves (`word64`).
- The block buffers and message schedules are allocated once per file and
  reused, since a native build never frees per-block temporaries.

The unit tests check the RFC and FIPS known answers; the end-to-end tests
check one million `a`s and the block boundaries (55, 56, 64, 111, 112 and
128 bytes) against values taken from `md5sum`, `sha1sum`, `sha256sum`,
`sha384sum` and `sha512sum`.

## Differences from the original

- Only these five verbs exist; the certificate, CA and store verbs of the
  real certutil are out of scope. Without a verb, certutil prints its
  summary (the real one runs `-dump`).
- `-hashfile` supports MD5, SHA1, SHA256, SHA384 and SHA512; MD2 and MD4
  give `NTE_BAD_ALGID`.
- `-encodehex` supports the types listed above (not the `NOCRLF` flags or
  other CryptBinaryToString types); `-decodehex` reads hex dumps whatever
  their layout, and base64 for the base64 types.
- Errors go to standard error. The HRESULT is returned as the exit status,
  so Linux shows only its low 8 bits.
- The usage shown for a verb with wrong arguments, `-?` and the summary are
  this project's own short texts, not Microsoft's help.
- Files are read whole into memory: hashing needs about twice the file's
  size, the conversions several times more (a 5 MB file takes under a
  second).
- An unreadable file (permissions) stops the program with the toolchain's
  `IoError` message: Loup 1.26.0 cannot catch it natively.
- `--help` and `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version
source/cli/args.loup           # options and verbs via win.switches
source/cli/usage.loup          # -? summary, per-verb usage, --version
source/cli/app.loup            # run(): parse, help, the verb dispatcher, exit status
source/commands/hashfile.loup  # -hashfile
source/commands/convert.loup   # -encode, -decode, -encodehex, -decodehex
source/commands/files.loup     # input and output checks
source/commands/results.loup   # HRESULTs, FAILED and success lines
source/hash/                   # md5, sha1, sha256, sha512 (and 384), common helpers
source/codec/                  # base64 with framing, hex dump formats
source/win/                    # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/certutil (make e2e)
specs/certutil/                # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
