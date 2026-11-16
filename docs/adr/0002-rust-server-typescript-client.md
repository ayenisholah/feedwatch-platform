# 0002: Rust on the server, TypeScript only in the client

**Status:** Accepted, 2026-11-16.

## Context

The project shows backend skill in RedStone's stack, which includes Rust and TypeScript. The owner asked for Rust for every server or worker service, and TypeScript only for the client.

## Decision

- The poller and API are Rust: Tokio, reqwest, Axum, serde and tracing.
- The web client is a Next.js static export (`output: "export"`). It has no server runtime, and the browser calls `/api/*` on the same origin.

## Consequences

- No Node process runs in production. The client is static files on S3 behind CloudFront.
- The client can't hide anything from the browser, so the API is public, read-only and rate-limited (GR-2).
- Dynamic routes become query strings, such as `/feed?chain=base&id=ETH`, because a static export can't render unknown paths.
