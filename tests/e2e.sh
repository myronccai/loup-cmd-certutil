#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# check_output NAME EXPECTED_FILE ACTUAL_FILE
# Compares a file the binary wrote with the expected bytes.
check_output() {
    if cmp -s "$2" "$3"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1 (output file differs)"
        diff <(od -c "$2") <(od -c "$3" 2>&1) | sed 's/^/    /' | head -10
    fi
}

# hash_case FILE ALGORITHM_ARG PRINTED_NAME HEX
# certutil -hashfile FILE [ALGORITHM_ARG] must print the hash block.
hash_case() {
    local file=$1 arg=$2 shown=$3 hex=$4
    local out="$shown hash of $file:"$'\n'"$hex"$'\n'"CertUtil: -hashfile command completed successfully."$'\n'
    if [ -n "$arg" ]; then
        check_both "hash $file $arg" 0 "$out" '' -hashfile "$file" "$arg"
    else
        check_both "hash $file (default)" 0 "$out" '' -hashfile "$file"
    fi
}

# failure VERB HRESULT_TEXT MESSAGE: the two lines of a failed verb.
failure() {
    printf 'CertUtil: -%s command FAILED: %s\nCertUtil: %s\n' "$1" "$2" "$3"
}

# The fixture tree, built under $TMP. aN is N letters "a" (block
# boundaries of the hashes), million is 1,000,000 of them.
W="$TMP/w"
mkdir -p "$W/sub"
cd "$W"
printf 'hello' > hello
: > empty
head -c 1000000 /dev/zero | tr '\0' a > million
for n in 55 56 64 111 112 128; do
    printf '%*s' "$n" '' | tr ' ' a > "a$n"
done
printf 'Hello, world!\n\0\377' > mixed.bin
nl=$'\n'
crlf=$'\r\n'

# -hashfile: known answers (FIPS 180 "a" x 1,000,000; block boundaries).
hash_case hello    ''       SHA1   aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d
hash_case hello    md5      MD5    5d41402abc4b2a76b9719d911017c592
hash_case hello    SHA256   SHA256 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
hash_case hello    sha384   SHA384 59e1748777448c69de6b800d7a33bbfb9ff1b463e44354c3553bcdb9c666fa90125a3c79f90397bdf5f6a13de828684f
hash_case hello    Sha512   SHA512 9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043
hash_case empty    SHA256   SHA256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
hash_case million  MD5      MD5    7707d6ae4e027c70eea2a935c2296f21
hash_case million  SHA1     SHA1   34aa973cd4c4daa4f61eeb2bdbad27316534016f
hash_case million  SHA256   SHA256 cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0
hash_case million  SHA512   SHA512 e718483d0ce769644e2e42c7bc15b4638e1f98b13b2044285632a803afa973ebde0ff244877ea60a4cb0432ce577c31beb009c5c2c49aa2e4eadb217ad8cc09b
hash_case a55      MD5      MD5    ef1772b6dff9a122358552954ad0df65
hash_case a56      MD5      MD5    3b0c8ac703f828b04c6c197006d17218
hash_case a64      MD5      MD5    014842d480b571495a4a0363793f7367
hash_case a55      SHA1     SHA1   c1c8bbdc22796e28c0e15163d20899b65621d65a
hash_case a56      SHA1     SHA1   c2db330f6083854c99d4b5bfb6e8f29f201be699
hash_case a64      SHA1     SHA1   0098ba824b5c16427bd7a1122a5a442a25ec644d
hash_case a55      SHA256   SHA256 9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318
hash_case a56      SHA256   SHA256 b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a
hash_case a64      SHA256   SHA256 ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb
hash_case a111     SHA512   SHA512 fa9121c7b32b9e01733d034cfc78cbf67f926c7ed83e82200ef86818196921760b4beff48404df811b953828274461673c68d04e297b0eb7b2b4d60fc6b566a2
hash_case a112     SHA512   SHA512 c01d080efd492776a1c43bd23dd99d0a2e626d481e16782e75d54c2503b5dc32bd05f0f1ba33e568b88fd2d970929b719ecbb152f58f130a407c8830604b70ca
hash_case a128     SHA512   SHA512 b73d1929aa615934e61a871596b3f3b33359f42b8175602e89f7e06e5f658a243667807ed300314b95cacdd579f3e33abdfbe351909519a846d465c59582f321
hash_case a112     SHA384   SHA384 187d4e07cb306103c69967bf544d0dfbe9042577599c73c330abc0cb64c61236d5ed565ee19119d8c31779a38f791fcd
check      "/hashfile, path with /" 0 "SHA1 hash of sub\\..\\hello:${nl}aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d${nl}CertUtil: -hashfile command completed successfully.${nl}" \
    /HASHFILE sub/../hello

# -hashfile failures (exit status: the HRESULT's low 8 bits).
check_both "unsupported algorithm" 8 '' "$(failure hashfile '0x80090008 (-2146893816 NTE_BAD_ALGID)' 'Invalid algorithm specified.')$nl" -hashfile hello MD4
check_both "missing file"          2 '' "$(failure hashfile '0x80070002 (WIN32: 2 ERROR_FILE_NOT_FOUND)' 'The system cannot find the file specified.')$nl" -hashfile nope.txt
check_both "missing directory"     3 '' "$(failure hashfile '0x80070003 (WIN32: 3 ERROR_PATH_NOT_FOUND)' 'The system cannot find the path specified.')$nl" -hashfile 'nodir\x'
check_both "a directory"           5 '' "$(failure hashfile '0x80070005 (WIN32: 5 ERROR_ACCESS_DENIED)' 'Access is denied.')$nl" -hashfile sub
hashfile_usage="Usage:${nl}  CertUtil [Options] -hashfile InFile [HashAlgorithm]${nl}  Print the hash of a file: MD5, SHA1 (the default), SHA256, SHA384 or SHA512.${nl}"
check_both "no file"               87 '' "${hashfile_usage}$(failure hashfile '0x80070057 (WIN32: 87 ERROR_INVALID_PARAMETER)' 'The parameter is incorrect.')$nl" -hashfile
check_both "verb help"             0 "$hashfile_usage" ''       -hashfile '-?'

# -encode / -decode: base64 in 64-character lines, CR LF, certificate frame.
ok() { printf 'Input Length = %s\nOutput Length = %s\nCertUtil: -%s command completed successfully.\n' "$2" "$3" "$1"; }
printf -- '-----BEGIN CERTIFICATE-----\r\naGVsbG8=\r\n-----END CERTIFICATE-----\r\n' > "$TMP/hello.b64"
check_both "encode"                0 "$(ok encode 5 66)$nl" ''   -encode hello hello.b64
check_output "encoded file"        "$TMP/hello.b64" hello.b64
line1=$(for i in $(seq 16); do printf 'YWFh'; done)
line2=$(for i in $(seq 5); do printf 'YWFh'; done)YQ==
printf -- '-----BEGIN CERTIFICATE-----\r\n%s\r\n%s\r\n-----END CERTIFICATE-----\r\n' "$line1" "$line2" > "$TMP/a64.b64"
check      "encode, two lines"     0 "$(ok encode 64 148)$nl"    -encode a64 a64.b64
check_output "64-character lines"  "$TMP/a64.b64" a64.b64
check      "decode"                0 "$(ok decode 148 64)$nl"    -decode a64.b64 a64.out
check_output "decoded file"        a64 a64.out
check      "encode empty"          0 "$(ok encode 0 56)$nl"      -encode empty empty.b64
check      "encode bytes"          0 "$(ok encode 16 82)$nl"     /Encode mixed.bin mixed.b64
check      "decode bytes"          0 "$(ok decode 82 16)$nl"     -decode mixed.b64 mixed.out
check_output "bytes round trip"    mixed.bin mixed.out
printf 'aGVs\nbG8=\n' > bare.txt
check      "decode bare base64"    0 "$(ok decode 10 5)$nl"      -decode bare.txt bare.out
check_output "bare decoded"        hello bare.out
printf -- '-----BEGIN X509 CRL-----\naGVsbG8=\n-----END X509 CRL-----\n' > crl.txt
check      "decode other label"    0 "$(ok decode 57 5)$nl"      -decode crl.txt crl.out
check_output "other label decoded" hello crl.out

# Conversion failures.
check_both "output exists"         80 '' "$(failure encode '0x80070050 (WIN32: 80 ERROR_FILE_EXISTS)' 'The file exists.')$nl" -encode hello hello.b64
check      "-f overwrites"         0 "$(ok encode 5 66)$nl"      -f -encode hello hello.b64
check_both "output is a directory" 5 '' "$(failure encode '0x80070005 (WIN32: 5 ERROR_ACCESS_DENIED)' 'Access is denied.')$nl" -f -encode hello sub
check_both "output directory missing" 3 '' "$(failure encode '0x80070003 (WIN32: 3 ERROR_PATH_NOT_FOUND)' 'The system cannot find the path specified.')$nl" -encode hello nodir/x.b64
check_both "decode non-base64"     13 '' "$(failure decode '0x8007000d (WIN32: 13 ERROR_INVALID_DATA)' 'The data is invalid.')$nl" -decode mixed.bin bad.out
check_both "decode missing input"  2 '' "$(failure decode '0x80070002 (WIN32: 2 ERROR_FILE_NOT_FOUND)' 'The system cannot find the file specified.')$nl" -decode nope.b64 x.out
decode_usage="Usage:${nl}  CertUtil [Options] -decode InFile OutFile${nl}  Write the bytes of a base64 file, framed or not.${nl}"
check_both "decode one argument"   87 '' "${decode_usage}$(failure decode '0x80070057 (WIN32: 87 ERROR_INVALID_PARAMETER)' 'The parameter is incorrect.')$nl" -decode a64.b64

# -encodehex / -decodehex: hex dumps in every type, base64 types too.
hex_line="48 65 6c 6c 6f 2c 20 77  6f 72 6c 64 21 0a 00 ff"
printf '0000\t%s   Hello, world!...\r\n' "$hex_line" > "$TMP/mixed.11"
check      "encodehex default"     0 "$(ok encodehex 16 74)$nl"  -encodehex mixed.bin mixed.hex
check_output "type 11 text"        "$TMP/mixed.11" mixed.hex
check      "decodehex default"     0 "$(ok decodehex 74 16)$nl"  -decodehex mixed.hex mixed.unhex
check_output "type 11 round trip"  mixed.bin mixed.unhex
printf '%s\r\n' "$hex_line" > "$TMP/mixed.4"
check      "encodehex 4"           0 "$(ok encodehex 16 50)$nl"  -encodehex mixed.bin m4 4
check_output "type 4 text"         "$TMP/mixed.4" m4
printf '0000\t%s\r\n' "$hex_line" > "$TMP/mixed.10"
check      "encodehex 10"          0 "$(ok encodehex 16 55)$nl"  -encodehex mixed.bin m10 10
check_output "type 10 text"        "$TMP/mixed.10" m10
printf '48656c6c6f2c20776f726c64210a00ff\r\n' > "$TMP/mixed.12"
check      "encodehex 12"          0 "$(ok encodehex 16 34)$nl"  -encodehex mixed.bin m12 12
check_output "type 12 text"        "$TMP/mixed.12" m12
check      "decodehex 12"          0 "$(ok decodehex 34 16)$nl"  -decodehex m12 m12.out 12
check_output "type 12 round trip"  mixed.bin m12.out
printf 'aGVsbG8=\r\n' > "$TMP/hello.1"
check      "encodehex 1: base64"   0 "$(ok encodehex 5 10)$nl"   -encodehex hello h1 1
check_output "type 1 text"         "$TMP/hello.1" h1
check      "decodehex 1"           0 "$(ok decodehex 10 5)$nl"   -decodehex h1 h1.out 1
check_output "type 1 round trip"   hello h1.out
for t in 0 3 5 9; do
    "$BIN" -encodehex million "m.$t" "$t" > /dev/null && "$BIN" -decodehex "m.$t" "m.$t.out" "$t" > /dev/null
    check_output "million, type $t round trip" million "m.$t.out"
done
check_both "type not supported"    87 '' "$(failure encodehex '0x80070057 (WIN32: 87 ERROR_INVALID_PARAMETER)' 'The parameter is incorrect.')$nl" -encodehex hello h7 7
check_both "type not a number"     87 '' "$(failure decodehex '0x80070057 (WIN32: 87 ERROR_INVALID_PARAMETER)' 'The parameter is incorrect.')$nl" -decodehex h1 hx x
check_both "decodehex non-hex"     13 '' "$(failure decodehex '0x8007000d (WIN32: 13 ERROR_INVALID_DATA)' 'The data is invalid.')$nl" -decodehex hello hz

# Arguments, help and version.
unknown="CertUtil: Unknown arg: -bogus${nl}CertUtil: The parameter is incorrect.${nl}"
check_both "unknown arg"           87 '' "$unknown"              -bogus hello
check_both "two verbs"             87 '' "CertUtil: Too many verbs: one at a time.${nl}CertUtil: The parameter is incorrect.${nl}" -encode -decode a b
check      "-- ends options"       2  ''                         -hashfile -- -bogus
usage_text=$("$BIN" '-?'; printf '.')
usage_text=${usage_text%.}
check_both "no verb: usage"        0 "$usage_text" ''
check      "/? usage"              0 "$usage_text"               '/?'
check      "--help"                0 "$usage_text"               --help
check      "--version"             0 $'certutil (loup-cmd-certutil) 0.1.0\n' --version
case "$usage_text" in
    *"-hashfile InFile [MD5|SHA1|SHA256|SHA384|SHA512]"*"-decodehex InFile OutFile [Type]"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL: usage lists the verbs" ;;
esac

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
