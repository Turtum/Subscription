# Subscription

Contents:
- `src/Subscription.sol` — subscription billing contract
- `src/interfaces/ISubscription.sol`
- `test/local/Subscription.t.sol`

Notes:
- Inside this workspace, `foundry.toml` uses `../lib` so the extracted repo can build without duplicating dependencies.
- If this becomes a standalone git repo, install its own dependencies under `lib/` and change `libs = ["lib"]`.
