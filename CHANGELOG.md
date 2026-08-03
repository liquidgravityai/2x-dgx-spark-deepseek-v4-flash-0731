# Changelog

All notable changes to the published two-node DGX Spark recipe and image are
recorded here.

## 2026-08-03 - Gilded Gnosis r24

### Published image

- Published immutable ARM64 tag
  `ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r24-vllm-7e92048-sparkinfer-2b9bf2a-cu132`.
- Published manifest digest
  `sha256:991d478bf4b96f64f536066d4c2645e23b4a5a3a93c4e65210bc3ce9ecd30ff4`.
- Moved `latest` to the same manifest digest.
- Updated the Compose default and release-layer Dockerfile to the r24 runtime.

### Runtime composition

- Replaced vLLM `e63a190ee1b48d051ccebce485de343dbe2b3505`
  with Gilded Gnosis r24 base
  `30038602b71395f481ef4a6edfe4fcf8551d9c15`, composed tree
  `f5981f14b4d39979bc0d799c020d42002b707257`, and structured-output tree
  `7e9204834e494728c9927f0f615d982271e4ffca`.
- Replaced SparkInfer `b0976b7fd46b5d34357a5f615822b86792676feb`
  with base `59216fa25f3d5fc9d4df2d052e02d05f763906e9` and composed tree
  `2b9bf2a4d15770c0c23e19cc13a75843f2f0a995`.
- Added the r24 compressed-MLA workspace reservation and physical cache-page
  stride fixes.
- Added native dense Trellis K6 support and the ARM64/SM121 ExLlamaV3 tree
  `9f3a773b494537580619b528f67c6261198ab237`.

### Fixed

- Preserved structured-output grammar-mask identity across DSpark adaptive
  verification compaction.
- Stopped treating asynchronous negative draft placeholders as grammar
  rejections.
- Removed the scheduler assertion that previously terminated the API during
  forced or required tool calls.

### Validation

- Started the published release layer on two DGX Sparks through the repository
  Compose recipe with TP2, fixed K6, greedy drafting, the automatic SPS curve,
  FP8 KV cache, and `MAX_NUM_SEQS=4`.
- Verified HTTP 200 health, matching image IDs on both ranks, and zero container
  restarts.
- Passed 16 of 17 tool-call behavior cases, including automatic, required,
  forced, strict-schema, parallel, streamed, and multi-turn tool-result flows.
- Passed 64 of 64 repeated tool calls at concurrency 8: 32 weather calls,
  16 local-time calls, and 16 strict-schema arithmetic calls.
- Found no assertion, traceback, EngineCore fatal error, CUDA/CUBLAS/NCCL
  error, OOM, or killed process in the captured head and worker logs.

### Known compatibility limits

- Forced named and streamed forced calls return valid `tool_calls` with
  `finish_reason: "stop"` instead of `"tool_calls"`. Clients should inspect
  `message.tool_calls`.
- `tool_choice: "none"` can produce blank content when a directly relevant
  tool remains in the request and the prompt does not explicitly forbid a
  tool call. Omit tools when disabled or include an explicit no-tool
  instruction.
- The performance table in the README is retained from the previous r16
  runtime and is not presented as an r24 throughput claim.

## 2026-08-02 - Initial public release

- Published
  `ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:vllm-e63a190-sparkinfer-b0976b7-cu132`
  at manifest digest
  `sha256:4a20904cffc5f2d80f753d65d78a143661ff494335dabba6c4658bb3662bf6ad`.
- Added the two-node Compose recipe, public release-layer Dockerfile, launcher,
  topology guidance, operational requirements, and sanitized example paths.
