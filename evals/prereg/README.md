# Pre-registration: three versions and their timestamp proofs

This folder holds the pre-registration for the delegation eval, in the three
versions that were written, and an OpenTimestamps proof for each one. A proof
shows that the file existed, byte for byte, before the Bitcoin block it names.
Version 1.2 is the version in force.

No file here has been edited since it was stamped. An edit would change the
hash and void the proof.

## The files

| Version | File | SHA-256 | Attested |
|---|---|---|---|
| 1.0 | `PREREGISTRATION-v1.0.md` | `8eccfbb2218229c3512d917faba87dd31a688307a694827e5bb56e8cecc2082f` | Bitcoin block 975620, 2026-11-12 |
| 1.1 | `PREREGISTRATION-v1.1.md` | `ac46aad70be6b0afa8d146e21360d86142ca61e86c32190c01bf12e78b6ca460` | Bitcoin block 975620, 2026-11-12 |
| 1.2 | `PREREGISTRATION-v1.2.md` | `51c1c5f4155c85446b100b51eb2286314f4f592781aa96fe19b9128310d2ca70` | Bitcoin block 975620, 2026-11-12 |

Each file has a proof beside it with the same name plus `.ots`.

The dates are the block's date in US Eastern time, as the client printed it.
Each proof carries attestations from four calendar servers, in blocks 975619,
975620 and 975645. The client reported block 975620 for all three versions.

## Verify a file yourself

1. Check the hash:

   ```
   sha256sum PREREGISTRATION-v1.2.md
   ```

   The output must match the table.

2. Check the proof with an OpenTimestamps client. With Node.js installed:

   ```
   npm install opentimestamps
   node node_modules/opentimestamps/ots-cli.js verify PREREGISTRATION-v1.2.md.ots
   ```

   Run it in the folder that holds both files. The client reads the `.md`
   file, follows the proof to a Bitcoin block header, and prints the block
   height and date. Without a local Bitcoin node it asks public block
   explorers for the header and says so.

   You can also drop the `.ots` file and the `.md` file on
   https://opentimestamps.org.

These proofs were upgraded and verified on 2026-11-18 with the JavaScript
client, version 0.4.9, in lite-client mode (block headers from public
explorers, no local node).

This repository checks text files out with LF line endings on every platform,
so a fresh clone gives the same bytes. If you copy a file through a tool that
rewrites line endings, the hash will not match.
