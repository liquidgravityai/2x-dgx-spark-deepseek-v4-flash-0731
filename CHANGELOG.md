# Changelog

All notable changes to the published two-node DGX Spark SGLang recipe and image
are recorded here.

## 2026-08-07 - SGLang r8 exclusive tool-generation release

### Correctness

- Reproduced the concurrency-dependent DSV4 tool-call defect with the exact
  64-request, concurrency-eight workload. r7 returned 117/128 valid calls;
  removing DSpark returned 116/128; forcing every advertised JSON schema
  returned 118/128; and Marlin previously returned 116/128. None fixed the
  generated-value corruption.
- Reduced only `max_running_requests`: concurrency two returned 127/128 while
  concurrency one returned 128/128 across two complete runs. This isolated
  overlapping DSV4 generation as the failure condition and agrees with upstream
  issue [#33397](https://github.com/sgl-project/sglang/issues/33397).
- Added a writer-preferring OpenAI chat generation gate. Tool-bearing requests
  now run exclusively against every other chat request; ordinary chat requests
  remain concurrent up to `MAX_NUM_SEQS=4`.

### Qualification

- The gated candidate passed two exact tool-stress runs and the published image
  passed a third: **192/192 valid calls**, including exact strict typed
  arguments, required calls, named calls, automatic calls, and correct protocol
  finish reasons.
- Four concurrent streaming tool calls passed while
  `sglang:num_running_reqs` remained at one. A mixed 512-token ordinary request
  and tool request also remained at one, proving the exclusive path spans the
  complete generation lifetime.
- Four ordinary 512-token requests reached four running requests and completed
  in 21.383 seconds versus 79.178 seconds of summed latency. The 8,192-token
  Tetris workload measured 58.20 output tok/s, 0.94% below the r7 median.
- Both final containers remained running with zero restarts and zero OOM kills;
  health returned HTTP 200, the smoke response was exactly `SGLANG_R8_OK`, and
  neither log contained a fatal signature.

### Published image

- Published immutable ARM64 tag
  `ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r8-sglang-d2c405f-toolgate-flashinfer-67f7637-cu132`.
- Published manifest digest
  `sha256:ed8afcb66d235ff02ca603c0f5bace9b11a7d6fd9ba4e8d7c70ac8b458b58bba`.
- Added patch SHA-256
  `6c3abff755b05c2d52554b79548df88bb0c54e7c652322d3cad31a99454710a8`
  and machine-readable
  `validation/sglang-r8-tool-generation-qualification.json`.
- Retained the package's vLLM-oriented `latest` tag unchanged.

## 2026-08-07 - Tool-call backend qualification

### Correctness

- Confirmed that the r7 performance overlay and live image already contain
  SGLang PR
  [#33568](https://github.com/sgl-project/sglang/pull/33568): DSV4 tools are
  serialized with `exclude_unset=True, by_alias=True`, matching the
  checkpoint's reference encoder. The original 117/128 tool-stress result
  therefore already measured this fix.
- Repeated the exact 64-request, concurrency-eight stress workload twice.
  FlashInfer MXFP4 returned 115/128 valid calls versus the prior 117/128;
  across all four runs it returned 232/256, or 90.6%. This is the same
  operating regime, not a meaningful improvement.

### Backend comparison

- Tested Marlin with the otherwise unchanged two-node r7 configuration.
  Marlin returned 116/128 valid calls, one more than the fresh FlashInfer
  pair but one fewer than the original FlashInfer pair.
- Rejected Marlin: the accuracy difference was noise-sized while mean wall
  time increased 12.0% and mean median request latency increased 9.7%.
- Explicitly pinned the retained `flashinfer_mxfp4` backend in Compose and
  `.env.example` so future SGLang defaults cannot silently change it.

### Release decision

- No new image was published: PR #33568 was already present and Marlin was
  not a better build. The immutable r7 image and digest remain current.
- Added `validation/sglang-r7-tool-backend-qualification.json` with the
  complete machine-readable comparison and restoration smoke result.

## 2026-08-06 - SGLang r7 bounded hybrid-SWA release

### Published image

- Published immutable ARM64 tag `ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r7-sglang-d2c405f-flashinfer-67f7637-cu132`.
- Published manifest digest
  `sha256:786fc402e4267bbc1c58f813865ff674ccbe790b99b22f0047af9dbd46f06f42`.
- Retained the package's vLLM-oriented `latest` tag unchanged.

### Correctness

- Added per-step eviction of out-of-window DSpark SWA KV entries. Before the
  fix, one request exhausted an intentionally reduced 11,008-token SWA pool
  and returned HTTP 500. The fixed tree completed all 13,000 requested tokens
  with zero retractions, restarts, or OOM kills.
- Pinned final SGLang tree
  `d46b115c1504b2896b3990c1a71c3d6c11e95e4e` and hybrid-SWA patch SHA-256
  `cc9f621236e38ca13c37e99355eac91d26369127294a020c224a9891734912ba`.

### Profiling

- Retained DSpark block size 5 with the r6 profiled compact-verification table.
- Rejected block size 7: compact mode failed CUDA-graph capture and profiled
  static mode reduced C1/C4 decode by 11.8%/22.7% and the 8,192-token Tetris
  workload by 16.7%.
- Rejected the FP4 DeepGEMM indexer as the general-purpose default: its 3.8%
  128K-prefill improvement came with 1.9%/2.4% C1/C4 decode regressions and an
  8.9% Tetris regression.
- The retained fixed profile measured 86.99 tok/s at C4, 2,199 prompt tok/s
  for 128K prefill, and 61.10 tok/s on the 8,192-token C1 Tetris workload.

### Validation

- Deployed the exact release image through the public Compose recipe on both
  Sparks. Both containers remained running with zero restarts and zero OOM
  kills; the canonical chat smoke returned exactly `SPARKINFER_OK`.
- Added the machine-readable `validation/sglang-r7-gb10.json` receipt.

## 2026-08-06 - SGLang r6 profiled DSpark release

### Published image

- Published immutable ARM64 tag `ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r6-sglang-d2c405f-flashinfer-67f7637-cu132`.
- Published manifest digest
  `sha256:4b9fd7e89a10d0333ee3e096ca25f9fa26e02a46dceae4fb016bc496fe4644d5`.
- Kept the package's vLLM-oriented `latest` tag unchanged.
- Added a release layer matching the repository's vLLM recipe structure.

### Runtime composition

- Pinned SGLang `d2c405f19df918c542c6cea9b1ddd59880e1e888`, source tree
  `b2b423131b41ef7ce4e458ac7384e49541c46ed6`, performance tree
  `b845e816dc7ddd34413834dc7a5b46586b2f5f49`, and final adaptive WO-A tree
  `445a046ec440c761c8bfae7950bb18f379392f4b`.
- Pinned SGL-Kernel `fdebc938f7f4d16fe6b9f55dcd9a767cf0899ea1`.
- Pinned FlashInfer `67f76379a145f19793896394974e29e610cda912` and final tree
  `d8567dec0ff48f11c0ab1d17a05e944d50e48f7a`.
- Recorded the qualified release-base image ID
  `sha256:b20aa35a5c1aba811b70239f9f9e5b5865d8a4ccad2d8efec9abf7c0226edaa9`.

### Serving profile

- Added a two-node TP2 Compose recipe aligned with the vLLM deployment UX.
- Retained a 270,000-token per-request limit, four running requests, FP8 E4M3
  KV cache, 8,192-token chunked prefill, and a 16,384-token prefill batch.
- Embedded the measured `dspark_sps_r6_profile.json` cost table in the image.
- Enabled DSpark block size 5, compact profiled verification, adaptive FP8 WO-A
  attention projections, TileLang/DeepGEMM mHC pre-normalization, and one CUDA
  launch connection.

### Validation

- Passed the canonical `SPARKINFER_OK` chat-completions smoke request.
- Passed two repeated 127,900-token exact-retrieval requests at a 61.33-second
  mean and 2,085 prompt tok/s.
- Measured C4 concurrency-4 sustained decode at 86.83 tok/s, 6.6% above the
  retained vLLM result.
- Measured the C1 8,192-token Tetris workload at 59.65 tok/s, 4.5% below the
  retained vLLM result.
- Both ranks retained zero restarts and zero OOM kills during qualification.

### Known limits

- The SGLang profile has not passed the vLLM recipe's identical four-way
  269,989-token ceiling test.
- Equivalent structured-output and tool-call qualification is not complete.
- Gamma 6 is incompatible with the checkpoint's fixed gamma-5 confidence head;
  it produced the invalid CUDA-graph capture shape `[4, 5, -1]`.
- The SPS table is specific to two GB10 nodes, TP2, block size 5, and compact
  verification.
