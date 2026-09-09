Fixes #4878

## Summary
The satellites in the Storj list (`us1.storj.io:7777`, `eu1.storj.io:7777`, `ap1.storj.io:7777`) have no node ID. The bundled uplink library (uplink.NET 2.14.3623) can only look up the node ID of the old `tardigrade.io` names, so creating an access from an API key failed for every listed satellite before any connection, with the error in #4878:

```
uplink: node id is required in satelliteNodeURL
```

`ResolveSatelliteAddress` now adds the node ID of a known satellite when the address has none. An address with a node ID and an unknown host are passed on as they are. Stored URLs and the satellite values in the UI keep the short address.

## Testing
- New tests in `StorjSatelliteAddressTests` for the known satellites, for addresses that are kept, and for every satellite in the list.
- By hand, with a well-formed but invalid API key, constructing the backend with `storj-auth-method=API key`:
  - master: `AccessException: uplink: node id is required in satelliteNodeURL`
  - this change: `AccessException: uplink: permission denied (Unauthorized API credentials)`, so the satellite was reached.
- The node IDs were checked against the satellites: with a wrong node ID the connection fails with `peer ID did not match requested ID`.
- Tests matching `Storj`: 22 passed. No new warnings.
- Not tested: a backup with a real Storj account.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
