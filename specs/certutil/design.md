# Design: certutil

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. `cli.args.parse_args`
declares the options and verbs as switches of the shared Windows parser,
so `-hashfile`, `/HashFile` and `-HASHFILE` are one verb. `run` handles
`--version`, `-?`, unknown arguments and repeated verbs, then the
template's dispatcher (`dispatch`, a `match` on the verb) calls
`run_hashfile` or one of the conversion verbs. Verbs check their files
first (`commands.files`), then compute with pure functions (`hash.*`,
`codec.*`), write, and report with `commands.results`.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options` (verb, operands, `-f`, unknown, verb count), `VERBS`, `certutil_switches`, `parse_args` |
| `source/cli/usage.loup` | `usage()`, `verb_usage(verb)`, `version_line()` |
| `source/cli/app.loup` | `run()` and `dispatch()` |
| `source/commands/hashfile.loup` | `canonical_algorithm`, `hash_hex`, `run_hashfile` |
| `source/commands/convert.loup` | `encoded_text`, `decoded_values`, `valid_type`, the four `run_*` verbs |
| `source/commands/files.loup` | `input_problem`, `output_problem`: the HRESULT a read or write would fail with |
| `source/commands/results.loup` | HRESULT constants, names, messages, `exit_code`, `failure_lines`, `success_line`, `fail` |
| `source/hash/common.loup` | 32- and 64-bit rotations and shifts, `word64`, `hex_word`, `load_block`, `padded_tail` |
| `source/hash/md5.loup`, `sha1.loup`, `sha256.loup`, `sha512.loup` | the compression functions and `*_hex(data)` |
| `source/codec/base64.loup` | `base64_encode`, `framed_text`, `certificate_text`, `payload`, `base64_decode` |
| `source/codec/hexdump.loup` | `hex_text(data, type)`, `address`, `hex_decode` |

## Hashing

Each algorithm reads the file with `readBytes`, compresses every full block
straight from the `bytes` (copied into one reused block buffer), then the
one or two blocks of `padded_tail` (the rest, `0x80`, zeros, the bit
length: 8 bytes little-endian for MD5, big-endian for SHA-1/SHA-256, 16
bytes for SHA-512). The message schedule is allocated once.

Words are Loup `int` (64-bit, wrapping). 32-bit algorithms mask with
`0xFFFFFFFF` after additions and use `x ^ 0xFFFFFFFF` for NOT; their
values are never negative, so `>>` is logical. SHA-512 lets additions wrap
at 2^64, uses `shr64` (`(x >> n) & ((1 << (64 - n)) - 1)`) for logical
shifts and `rotr64` built on it, never compares words, and builds its
constants and initial values from 32-bit halves with `word64`. SHA-384 is
SHA-512 with its own initial values, cut to six words.

## Encoding

`base64_pieces` produces the base64 characters one table entry at a time,
with CR LF after every 64 when framing: a native build never frees
temporary strings, and slicing a long string by position is linear, so the
text is never assembled and then cut. `payload` takes the lines between a
`-----BEGIN` line and the next `-----END` line (or every line);
`base64_decode` skips whitespace, accepts missing padding, and returns
`[-1]` for anything else. `hex_text` uses tables of the 256 two-digit
strings and text-column characters; `hex_decode` skips an offset up to a
TAB and, in spaced layouts, reads only the 48-character hex column.

Decoded bytes are written with `writeBytes(path, bytesFromInts(values))`
and the file's existence is checked afterwards (native `writeBytes` fails
silently); empty output is written with `writeText`.

## Differences from the original

See the README: five verbs only; MD2/MD4 unsupported; the listed
`-encodehex` types only; errors on standard error; the HRESULT's low 8
bits as the Linux exit status; this project's own usage texts; whole files
in memory; an unreadable file stops the program with Loup's `IoError`.

## Error handling

Every failure goes through `results.fail(verb, hr)`, which prints the two
FAILED lines on standard error and returns `exit_code(hr)`. Files are
checked before any read or write, because a native `IoError` cannot be
caught. An unexpected exception is printed as `CertUtil: message` and gives
0x80070057.

## Testing

- `tests/hash_test.loup`: RFC 1321 and FIPS 180-2 known answers for all
  five algorithms, including two-block messages.
- `tests/common_test.loup`: rotations, 64-bit wrap and shifts, padding.
- `tests/codec_test.loup`: RFC 4648 vectors, decoding errors, framing,
  payload extraction, every hex layout and its decoding.
- `tests/results_test.loup`: FAILED lines and exit codes.
- `tests/args_test.loup`, `tests/app_test.loup`: verbs, options, statuses.
- `tests/e2e.sh`: the native binary on fixtures under `$TMP`: one million
  `a`s and block-boundary sizes for every algorithm (values from the
  system's `*sum` tools), exact output files, round trips, every failure.
