# USDT/LKR P2P Rate Widget

A native macOS desktop widget that tracks the Binance P2P USDT/LKR rate, shows
whether it is moving up or down, and charts history collected every 5 minutes.

Status: **design approved, implementation not started.**
See [the design spec](docs/superpowers/specs/2026-09-07-p2p-lkr-widget-design.md).

## Why

Binance P2P is where USDT/LKR price discovery actually happens, but the web page
shows only a live snapshot. You cannot tell whether today's 330.66 is a good
moment to sell or the bottom of a two-day slide.

## How it reads the rate

The P2P page is backed by a public, unauthenticated JSON endpoint, so no
scraping is involved:

```
POST https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search
```

The headline number is **not** the top row of the page. It is the best price from
an ad that can actually fill your configured trade size. At the time of writing
the top ad quoted 332.00 LKR but required a minimum order of 499,999 LKR
(~1,500 USDT); the real tradeable rate for 500 USDT was 331.00. Filtering for
fillability is the difference between a useful chart and one that spikes on ads
nobody can trade.

## Layout

| Path | Contents |
|---|---|
| `P2PKit/` | Shared Swift package: API client, models, store, metrics, alerts |
| `P2PMonitor/` | App target: 5-minute poller, settings, detail window |
| `P2PWidget/` | Widget extension (read-only) |
| `fixtures/` | Recorded API responses driving the offline test suite |
| `tools/` | `p2p.sh`, a standalone shell client for poking at the endpoint |

## tools/p2p.sh

Queries the endpoint directly, no build required:

```sh
./tools/p2p.sh SELL 10   # ads for you to sell USDT into
./tools/p2p.sh BUY 10    # ads for you to buy USDT from
```

## Requirements

macOS 14+ (developed on 26.6), Xcode 26+, `xcodegen` (`brew install xcodegen`),
and a signing identity whose team can carry an App Group entitlement.

The Xcode project is generated, not committed. Run `make project` after cloning,
and again after adding or renaming any source file.
