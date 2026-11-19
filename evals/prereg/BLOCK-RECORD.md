# Block record: the Bitcoin blocks that attest the pre-registration

This file records which Bitcoin blocks attest the three pre-registration
versions in this folder, and where each number came from. The raw client
output behind it is in `VERIFY-OUTPUT.txt`.

## In one sentence

Every version (1.0, 1.1 and 1.2) is attested by Bitcoin block 975620, whose
header time is 2026-11-13 02:26:51 UTC (2026-11-12 21:26:51 US Eastern).

It is not exact to say that one block holds all the timestamps. Each proof
carries four attestations, from four calendar servers, and they sit in three
blocks. Block 975620 is the one the client reports for all three versions.

## The blocks

| Height | Block hash | Header time (UTC) | Merkle root |
|---|---|---|---|
| 975619 | `00000000000000000000a047e43f85cd3bd63887f20e3149cdf6071988e2b50a` | 2026-11-13 02:29:54 | `ddc4bc9b2e8ef9e1fe9af2c2887fd7c93f6098fab695b36b25b6b1c33c4ced7a` |
| 975620 | `0000000000000000000046b2da1a22ab790ae51228a95079d8bce7a58438e0f5` | 2026-11-13 02:26:51 | `449d285ade5728aa8c60fa14c5a43113200d0577210d1cfd8705807ae1123dfa` |
| 975645 | `000000000000000000002eea021204866831c80fa90caa5191d7fd754ceab66e` | 2026-11-13 07:56:01 | `884a68421a1763fb9fb89a9aaecc27aa145adaca707f375b629cab45654f2096` |

Header times as Unix seconds: 1794536994, 1794536811, 1794556561.

Source: the public APIs of blockstream.info and mempool.space, read on
2026-11-19. Both returned the same height, hash, timestamp and merkle root
for each block.

Block 975619 is the parent of 975620, yet its header time is three minutes
later. A block's header time is set by its miner and is not exact. Read these
times as "about 02:30 UTC on 2026-11-13", not to the second.

## Which block attests which version

The same four calendar servers stamped every version, and each server's
attestation landed in the same block for all three.

| Calendar server | Block | v1.0 | v1.1 | v1.2 |
|---|---|---|---|---|
| alice.btc.calendar.opentimestamps.org | 975620 | yes | yes | yes |
| bob.btc.calendar.opentimestamps.org | 975620 | yes | yes | yes |
| finney.calendar.eternitywall.com | 975645 | yes | yes | yes |
| btc.calendar.catallaxy.com | 975619 | yes | yes | yes |

Source: the `info` output for each proof, in `VERIFY-OUTPUT.txt`. Each
`BitcoinBlockHeaderAttestation(height)` line follows the calendar it belongs to.

| Version | File SHA-256 | Client's verify result |
|---|---|---|
| 1.0 | `8eccfbb2218229c3512d917faba87dd31a688307a694827e5bb56e8cecc2082f` | Bitcoin block 975620 attests existence |
| 1.1 | `ac46aad70be6b0afa8d146e21360d86142ca61e86c32190c01bf12e78b6ca460` | Bitcoin block 975620 attests existence |
| 1.2 | `51c1c5f4155c85446b100b51eb2286314f4f592781aa96fe19b9128310d2ca70` | Bitcoin block 975620 attests existence |

The client prints the date as "2026-11-12 EST". That is the same moment as
2026-11-13 02:26:51 UTC.

## What this shows and what it does not

- It shows that each version existed, byte for byte, by the time block 975620
  was mined, about 02:30 UTC on 2026-11-13.
- It does not show the order of the versions. All three share the same blocks.
- It does not show when a version was written, only that it was no later than
  the block.

## How the check was run

- Client: the OpenTimestamps JavaScript client, version 0.4.9, commands
  `verify` and `info`, run on 2026-11-19 at 04:25 UTC.
- No local Bitcoin node was used. The client took block headers from public
  block explorers and says so in its output ("Lite-client verification").
  The block data in the table above was then read separately from two
  explorers, which agree.
- A reader with a Bitcoin node can repeat the check without trusting any
  explorer. See `README.md` in this folder for the commands.
