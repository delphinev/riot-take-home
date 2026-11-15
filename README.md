# Riot Take-Home — JSON Encryption & Signing API

A Rails API with four JSON endpoints: `/encrypt`, `/decrypt`, `/sign` and `/verify`.

The challenge statement is in [docs/INSTRUCTIONS.md](docs/INSTRUCTIONS.md).

## Getting started

Requires Ruby 3.4.2 (see `.ruby-version`). No database and no environment variable are needed locally.

```bash
bundle install
bin/rails server
```

Health check:

```bash
curl -i http://localhost:3000/up
```

## Configuration

| Variable | Required | Description |
|---|---|---|
| `HMAC_SECRET` | In production | Key used by `/sign` and `/verify`, at least 32 bytes. The app **refuses to boot** if it is missing or shorter. Development and test use a fixed, public key. |
| `SECRET_KEY_BASE` | In production | Required by Rails itself. |

Generate a value with `bin/rails secret`. The Docker image runs in production, so it needs both.

## API

Every endpoint takes a `POST` with a JSON body and `Content-Type: application/json`.

### `POST /encrypt`

Encrypts every top-level value of a JSON object. Nested objects are encrypted as a single value.

```bash
curl -s -w '\n' http://localhost:3000/encrypt -H 'Content-Type: application/json' \
  -d '{"name":"John Doe","age":30,"contact":{"email":"john@example.com","phone":"123-456-7890"}}'
```

```json
{"name":"enc:base64:IkpvaG4gRG9lIg==","age":"enc:base64:MzA=","contact":"enc:base64:eyJlbWFpbCI6ImpvaG5AZXhhbXBsZS5jb20iLCJwaG9uZSI6IjEyMy00NTYtNzg5MCJ9"}
```

### `POST /decrypt`

Decrypts the values produced by `/encrypt` and returns every other value unchanged.

```bash
curl -s -w '\n' http://localhost:3000/decrypt -H 'Content-Type: application/json' \
  -d '{"name":"enc:base64:IkpvaG4gRG9lIg==","birth_date":"1998-11-19"}'
```

```json
{"name":"John Doe","birth_date":"1998-11-19"}
```

### `POST /sign`

Signs any JSON value with HMAC-SHA256 and returns the signature as lowercase hex. The order of the keys does not change it.

```bash
curl -s -w '\n' http://localhost:3000/sign -H 'Content-Type: application/json' \
  -d '{"message":"Hello World","timestamp":1616161616}'
```

```json
{"signature":"1937ac88942e0ec0f277f4d2398917d4019a22ef920169987f50587c19b3944b"}
```

This signature comes from the development key; any other `HMAC_SECRET` gives another one.

### `POST /verify`

Takes exactly a `signature` and the `data` it signs. Answers `204 No Content` if the signature matches, `400` otherwise.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/verify -H 'Content-Type: application/json' \
  -d '{"signature":"1937ac88942e0ec0f277f4d2398917d4019a22ef920169987f50587c19b3944b","data":{"timestamp":1616161616,"message":"Hello World"}}'
```

```
204
```

### Errors

```json
{"error":{"code":"invalid_payload","message":"request body must be a JSON object"}}
```

| Status | Code | When |
|---|---|---|
| 400 | `invalid_json` | The body is not valid UTF-8 JSON, has duplicate keys, is nested more than about 100 levels, or holds a number out of range |
| 400 | `invalid_payload` | `/encrypt` or `/decrypt` did not receive an object; `/verify` did not receive exactly a string `signature` and `data` |
| 400 | `corrupted_value` | A value carries the `enc:base64:` prefix but cannot be decrypted |
| 400 | `invalid_signature` | `/verify`: the signature does not match the data |
| 415 | `unsupported_media_type` | The `Content-Type` is not `application/json` |

## Architecture

Controllers only translate HTTP; the logic lives in small objects under `lib/`, each tested on its own.

```
ApplicationController     Content-Type check, JSON in and out (StrictJson), error format
├── EncryptionController  /encrypt, /decrypt → PayloadEncryptor → Encryptors::Base64
└── SignatureController   /sign, /verify     → PayloadSigner    → CanonicalJson + Signers::Hmac
```

`lib/crypto.rb` is the only place that picks the algorithms. Replacing Base64 or HMAC means writing a class with the same methods (`algorithm`, `encrypt`, `decrypt` / `sign`, `verify`) and changing one line there.

## Design decisions

### Encryption

- **Values are serialized as JSON before being encrypted**, so their type survives the round trip: `30` comes back as a number, and the number `30` and the string `"30"` encrypt differently.
- **Encrypted values carry an `enc:<algorithm>:` prefix.** Many plain strings are valid Base64 (`"MTIz"`), so only prefixed values are decrypted.
- **A prefixed value that cannot be decrypted is a 400**, rather than being returned as is: the client would otherwise take ciphertext for plain text. This includes a plain string that happens to start with `enc:base64:`.
- **The root must be an object**: the statement encrypts "properties at depth 1".

### Signature

- **The signature depends on the value, not on how it is written**: the data is serialized canonically first, with keys sorted at every depth. Array order is kept.
- **`1` and `1.0` sign the same**: JSON has a single number type.
- **Signatures are compared in constant time**, so response times reveal nothing about a forged one.
- **`/verify` accepts exactly `signature` and `data`**: an extra field would look signed while it is not.

### JSON in and out

- **The body is read once, by the app, never through Rails `params`**, which would overwrite keys such as `action` and mix in query string parameters.
- **Parsing is strict**: invalid UTF-8 and numbers such as `1e400` (parsed as `Infinity`) are rejected with a 400, instead of failing later with a 500.
- **Whatever is accepted can be written back**: the parser bounds nesting, so JSON is written without the generator's own, stricter limit.
- **Numbers are doubles**, as in JavaScript: `0.1` and `0.10000000000000001` are the same number, and `1e-400` reads as `0`. Integers stay exact at any size.
- **Request parameters are never logged**: every value is filtered.

## Running the tests

```bash
bundle exec rspec
```

Unit specs cover each object in `lib/`; request specs cover the HTTP contract and the statement's examples. `spec/requests/round_trip_spec.rb` checks the statement's two guarantees on a list of edge cases: `/decrypt` restores what `/encrypt` returns, and `/verify` accepts what `/sign` returns.

`bin/ci` runs RuboCop, bundler-audit, Brakeman and the specs. The GitHub workflow runs the same checks on every push to `main` and every pull request.

## How this was built

I wrote this with an AI coding assistant (Claude Code), as a pair: I made the design
decisions, reviewed every change before committing it, and committed each step myself.

- **Small commits, reviewed one by one**, each one green (`bin/ci`), so that the history
  can be read commit by commit.
- **Behaviour checked, not assumed**: how the json gem and Rails actually handle edge cases
  (invalid UTF-8, `1e400`, form-encoded bodies) was tested before writing the code that
  depends on it.
- **A second AI review** of the finished history found that a value accepted by `/encrypt`
  could fail on `/decrypt` at the nesting limit; it is fixed and tested in its own commit.

## In production

Some things are simplified on purpose. A production version would also:

- **Authenticate clients.** As it stands, anyone can get any data signed or decrypted.
- **Encrypt for real**: Base64 is only an encoding, readable by anyone. A real cipher would
  need a secret key, kept out of the code, with each value carrying the id of its key so
  that keys can be rotated.
- **Keep keys in a KMS** or a secret manager, with rotation.
- **Reject replayed signatures**: today, a valid signature is accepted forever.
- **Replace Rails' default request logs** with structured logs that omit parameters (e.g. lograge). Every parameter value is filtered, but not parameter names: a JSON body sent without `Content-Type: application/json` is parsed by Rails as a form, so the whole body becomes a parameter name and reaches the logs, although the API answers 415.
- **Limit body size at the proxy** (e.g. Nginx `client_max_body_size`).
