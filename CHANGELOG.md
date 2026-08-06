# Changelog

All notable changes to the published two-node DGX Spark SGLang recipe and image
are recorded here.

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
