# Changelog

All notable changes to the published two-node DGX Spark SGLang recipe and image
are recorded here.

## 2026-08-06 - SGLang r6 profiled DSpark release

### Published image

- Published immutable ARM64 tag `ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r6-sglang-d2c405f-flashinfer-67f7637-cu132`.
- Published manifest digest `PENDING_PUBLICATION`.
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
