# Requirements: certutil

## Introduction

`certutil` is the Windows certificate tool; scripts mostly use it to hash
files and to convert files to and from base64 and hexadecimal. This
repository recreates those five verbs in Loup for Linux, with the hash
algorithms in pure Loup (the Lite edition has no crypto library), and
certutil's output, messages and ERRORLEVELs.

## Requirements

### Requirement 1: Verbs and options

**User Story:** As a script author, I want certutil's command-line shape.

#### Acceptance Criteria

1. THE program SHALL accept the verbs `-hashfile`, `-encode`, `-decode`,
   `-encodehex`, `-decodehex` and the options `-f` and `-v`, with `-` or
   `/`, in any case, and dispatch to the verb.
2. WHEN another `-word` appears before `--`, THE program SHALL print
   `CertUtil: Unknown arg: -word` and `CertUtil: The parameter is
   incorrect.` and exit with 0x80070057; WHEN two verbs are given, it SHALL
   fail the same way.
3. WHEN a verb has the wrong number of arguments, THE program SHALL print
   the verb's usage and the FAILED lines for 0x80070057.
4. WHEN `-?` is given, THE program SHALL print a summary of the verbs, or
   of the verb given with it, and exit with 0; without a verb it SHALL
   print the summary.

### Requirement 2: -hashfile

**User Story:** As a user, I want to check a file's hash.

#### Acceptance Criteria

1. WHEN `-hashfile FILE [ALG]` is given, THE program SHALL print
   `ALG hash of FILE:`, the digest in lower-case hexadecimal, and
   `CertUtil: -hashfile command completed successfully.`
2. THE program SHALL support MD5, SHA1 (the default), SHA256, SHA384 and
   SHA512, named in any case, and SHALL match RFC 1321 and FIPS 180-4.
3. WHEN the algorithm is not supported, THE program SHALL fail with
   `0x80090008 (-2146893816 NTE_BAD_ALGID)` and
   `Invalid algorithm specified.`

### Requirement 3: base64

**User Story:** As a user, I want to move binary files through text.

#### Acceptance Criteria

1. WHEN `-encode IN OUT` is given, THE program SHALL write
   `-----BEGIN CERTIFICATE-----`, the base64 of IN in lines of 64
   characters, and `-----END CERTIFICATE-----`, every line ending in CR LF.
2. WHEN `-decode IN OUT` is given, THE program SHALL write the bytes of the
   base64 between a `-----BEGIN ...-----` line and the next `-----END`
   line, or of the whole text when there is no frame, ignoring whitespace;
   WHEN the text is not base64 it SHALL fail with
   `0x8007000d (WIN32: 13 ERROR_INVALID_DATA)`.
3. Each conversion SHALL print `Input Length = N`, `Output Length = N` and
   the success line.

### Requirement 4: Hexadecimal

**User Story:** As a user, I want hex dumps of files and back.

#### Acceptance Criteria

1. WHEN `-encodehex IN OUT [TYPE]` is given, THE program SHALL write type
   11 by default (offset, TAB, 16 hex bytes with a wider gap after 8, the
   text column), or type 4, 5, 10, 12, or the base64 types 0, 1, 3, 9.
2. WHEN `-decodehex IN OUT [TYPE]` is given, THE program SHALL read any of
   the hex layouts (or base64 for a base64 type) back into bytes; WHEN the
   text is not hexadecimal it SHALL fail with ERROR_INVALID_DATA.
3. WHEN TYPE is not supported, THE program SHALL fail with 0x80070057.

### Requirement 5: Files and errors

**User Story:** As a script author, I want certutil's failures.

#### Acceptance Criteria

1. WHEN the input file is missing, its directory is missing, or it is a
   directory, THE program SHALL fail with ERROR_FILE_NOT_FOUND,
   ERROR_PATH_NOT_FOUND or ERROR_ACCESS_DENIED.
2. WHEN the output file exists and `-f` is not given, THE program SHALL
   fail with `0x80070050 (WIN32: 80 ERROR_FILE_EXISTS)` and `The file
   exists.`; WHEN it is a directory or its directory is missing, with
   ERROR_ACCESS_DENIED or ERROR_PATH_NOT_FOUND.
3. A failure SHALL print `CertUtil: -VERB command FAILED: 0xHRESULT (NAME)`
   and `CertUtil: MESSAGE` on standard error and exit with the HRESULT as
   a signed 32-bit number.
