# Changelog

All notable changes to the published two-node DGX Spark recipe and image are
recorded here.

## 2026-08-04 - Gilded Gnosis r27 and 1M-token aggregate KV profile

### Published image

- Published immutable ARM64 tag
  `ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r27-vllm-966d57c-sparkinfer-bbbdccc-cu132`.
- Published manifest digest
  `sha256:cef61238cfa7cf528bd17d2ecb09a3a3c62975dc80ac184435bef8ea457e4437`.
- Moved `latest` to the same manifest digest.
- Updated the Compose default and release-layer Dockerfile to r27.

### Runtime composition

- Replaced the r24 vLLM tree
  `f5981f14b4d39979bc0d799c020d42002b707257` with Gilded Gnosis r27
  tree `966d57c8c1d9f643eaac8aa231c6e1027936ef2a` on unchanged base
  `30038602b71395f481ef4a6edfe4fcf8551d9c15`.
- Reapplied the qualified structured-output overlay as exact result tree
  `daf73ac387b2d410f8c8985fc707073c884b5ab7`.
- Replaced the r24 SparkInfer tree
  `2b9bf2a4d15770c0c23e19cc13a75843f2f0a995` with r27 base
  `272a84bd97ce791a1e92d1f3a0da3dd5f3c6565f` and tree
  `bbbdccc338a2691d780ed160db54ef121c3a61c9`.
- Pinned InstantTensor
  `49b4010afc1cae0441e71fe0b0bffc24fa05e932`, LMCache tree
  `9a05c8818bae48d15b79c7e876418bb813c08cd0`, and the retained
  ARM64/SM121 ExLlamaV3 tree
  `9f3a773b494537580619b528f67c6261198ab237`.
- The reproducible upstream release is
  [`blackwell-llm-docker@74563bb`](https://github.com/local-inference-lab/blackwell-llm-docker/commit/74563bbfd789a297ca577da5dca049ab0b4b33e1).

### Gilded Gnosis r27 changes included

- [vLLM #235](https://github.com/local-inference-lab/vllm/pull/235)
  adds the official DeepSeek-V4-Flash-0731 low/high/max reasoning-effort
  prompts and preserves system/developer tool placement in both Python and
  Rust renderers.
- The current [vLLM #217](https://github.com/local-inference-lab/vllm/pull/217)
  head keeps native-tiering workers and the delayed scheduler on one named L1
  backing, removes redundant scheduler prefault, and cleans failed rendezvous
  state.
- [InstantTensor #19](https://github.com/scitix/InstantTensor/pull/19)
  attempts whole host registration, then bounded segmented registration, then
  a runtime-pinned allocation fallback.
- The inherited SparkInfer r25/r26 changes add dynamic mixed-Trellis expert
  counts and correct TP4/DCP4 automatic prefill policy. Neither path is active
  in this TP2 DeepSeek profile.
- The upstream fixed-K5 default was not copied. This release preserves the
  previously qualified fixed-K6, greedy-draft, automatic-SPS profile.
- Native KV offload, LMCache, and dynamic mixed-Trellis execution remain
  disabled in the published Compose recipe.

### Aggregate KV capacity

- Added `KV_CACHE_MEMORY_BYTES=19000000000` as an explicit per-rank default.
- The final public image reserved 17.7 GiB per rank and reported 1,034,442
  aggregate GPU KV tokens, or 3.95 times the 262,144-token per-request limit.
- A preceding 20,000,000,000-byte sizing run exposed 1,088,923 tokens and
  completed four concurrent measured 239,988-token exact-retrieval prompts.
  The published profile uses the more conservative 19,000,000,000-byte value.
- “1M-token KV” describes aggregate concurrent cache capacity. The qualified
  per-request maximum remains 262,144 tokens.

### Validation

- Reproduced the r27 source composition locally on Linux ARM64 and verified
  every vLLM, SparkInfer, InstantTensor, ExLlamaV3, and overlay result tree.
- Passed the upstream release-composition gate and 35 focused DeepSeek
  renderer/capacity tests; one unrelated optional dependency test was skipped.
- Started the exact public release layer on two DGX Sparks with TP2/DCP1,
  fixed K6, greedy drafting, automatic SPS, FP8 KV, and four sequences.
- Verified official low/high/max prompt prefixes, developer-before-tools
  placement, one deduplicated tool block, and a required tool call from a
  developer-plus-user request.
- Passed an exact-retrieval request with a measured 249,991-token prompt in
  173.590 seconds on the final published tag.
- Passed 16 of 17 tool-call behavior cases and 64 of 64 repeated tool calls at
  concurrency 8. The one failure is the retained `tool_choice: "none"` model
  behavior documented below.
- Both containers remained running with zero restarts and zero OOM kills. The
  captured head and worker logs contained no assertion, traceback, EngineCore
  fatal error, CUDA/CUBLAS/NCCL error, OOM, or killed process.

### Known limits

- Forced named and streamed forced calls return valid `tool_calls` with
  `finish_reason: "stop"` instead of `"tool_calls"`. Clients should inspect
  `message.tool_calls`.
- `tool_choice: "none"` can produce blank content when a directly relevant
  tool remains in the request and the prompt does not explicitly forbid a
  tool call. Omit tools when disabled or include an explicit no-tool
  instruction.
- Native KV offload, LMCache, and the inherited mixed-Trellis/TP4-DCP4 paths
  are present but unqualified by this deployment.
- The performance table in the README is retained from r16 and is not an r27
  throughput claim.

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

### Gilded Gnosis / vLLM changes included

- [vLLM #229](https://github.com/local-inference-lab/vllm/pull/229)
  derives compressed-MLA scratch capacity from the cache's physical layout
  contract instead of assuming only the logical 584-byte token payload. This
  closes the TP2 long-concurrency workspace under-reservation reported in the
  upstream release.
- [vLLM #217](https://github.com/local-inference-lab/vllm/pull/217)
  adds one shared native-offload mmap, decimal byte sizing, unlink-after-map
  lifetime, isolated registration failures, and row-stride-aware segmented
  host registration with 64-KiB alignment.
- [vLLM #218](https://github.com/local-inference-lab/vllm/pull/218)
  preserves sliding-window attention, MTP/EAGLE tails, replay boundaries,
  retention intervals, and shared-prefix tails when native CPU KV offload is
  used.
- [vLLM #216](https://github.com/local-inference-lab/vllm/pull/216)
  assigns semantic identities to PCIe graph channels so independent eager and
  captured collectives do not alias because of local capture order.
- [vLLM #228](https://github.com/local-inference-lab/vllm/pull/228)
  adds qualified mixed K3/K4 EXL3 prefill, optional online dense Trellis
  6-bit conversion, and persistent per-rank converted-weight caches with
  checkpoint- and geometry-based invalidation, locking, and atomic writes.
- [vLLM #230](https://github.com/local-inference-lab/vllm/pull/230)
  keeps broadcast mHC preprocessing behind the custom-operation compile
  boundary, preserving full-graph compilation.

### SparkInfer changes included

- [SparkInfer #106](https://github.com/local-inference-lab/sparkinfer/pull/106)
  accepts exact-payload and padded compressed-MLA pages and derives decode,
  single-GPU prefill, and multi-GPU prefill strides from the physical cache.
  It does not copy or replace the cache allocation.
- [SparkInfer #112](https://github.com/local-inference-lab/sparkinfer/pull/112)
  consolidates W4A16 planning and CUDA-graph safeguards, exact paired-M8 mixed
  K3/K4 prefill, the validated block-32 mixed geometry, and the native dense
  Trellis 6-bit linear runtime. The required JIT sources and upstream license
  are packaged in the image.
- [SparkInfer #113](https://github.com/local-inference-lab/sparkinfer/pull/113)
  makes named eager and CUDA-graph PCIe channels deterministic across ranks,
  preallocates staged buffers with device-side generation tracking, and makes
  CUDA-IPC teardown coordinated and retryable after partial failures.

The Trellis “K6” above means a 6-bit weight format; it is separate from this
deployment's `NUM_SPECULATIVE_TOKENS=6` setting. The r24 image contains the
native-offload and online-EXL3 capabilities, but the published Compose profile
does not enable either one.

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
