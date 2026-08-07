# 2x DGX Spark SGLang Recipe for DeepSeek V4 Flash 0731

A pinned, tested two-node SGLang deployment for
[`deepseek-ai/DeepSeek-V4-Flash-0731`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731)
on two NVIDIA DGX Spark systems.

The container contains the ARM64/CUDA runtime, SGLang, FlashInfer, SGL-Kernel,
B12X, DeepGEMM, TileLang, and the qualified DSpark speculative-decoding
configuration. Model weights are **not** included; mount the same pinned model
revision on both nodes.

## Published image

```text
ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r8-sglang-d2c405f-toolgate-flashinfer-67f7637-cu132
```

Published manifest digest:

```text
ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731@sha256:ed8afcb66d235ff02ca603c0f5bace9b11a7d6fd9ba4e8d7c70ac8b458b58bba
```

Use the immutable tag for reproducible deployments. This SGLang branch does
not move the repository package's vLLM-oriented `latest` tag.

| Component | Pinned value |
|---|---|
| Architecture | Linux ARM64 / NVIDIA GB10 (SM 12.1a) |
| CUDA | 13.2 |
| Qualified base image ID | `sha256:e15a9e6743edd53584a6f041d9b32dbf9997d4453150e6beb6089b7056524508` |
| SGLang | `d2c405f19df918c542c6cea9b1ddd59880e1e888` |
| SGLang source tree | `b2b423131b41ef7ce4e458ac7384e49541c46ed6` |
| SGLang performance tree | `b845e816dc7ddd34413834dc7a5b46586b2f5f49` |
| SGLang adaptive WO-A tree | `445a046ec440c761c8bfae7950bb18f379392f4b` |
| SGLang bounded hybrid-SWA tree | `d46b115c1504b2896b3990c1a71c3d6c11e95e4e` |
| Hybrid-SWA patch SHA-256 | `cc9f621236e38ca13c37e99355eac91d26369127294a020c224a9891734912ba` |
| Exclusive tool-generation patch SHA-256 | `6c3abff755b05c2d52554b79548df88bb0c54e7c652322d3cad31a99454710a8` |
| SGL-Kernel | `fdebc938f7f4d16fe6b9f55dcd9a767cf0899ea1` |
| FlashInfer | `67f76379a145f19793896394974e29e610cda912` |
| FlashInfer final tree | `d8567dec0ff48f11c0ab1d17a05e944d50e48f7a` |
| Model revision | `9e165c30e2704aec5d9d593cce3eebd58bbef1cb` |
| Topology | 2 nodes, 1 GB10 per node, tensor parallel size 2 |

The full r8 correctness, concurrency, performance, source, and image receipt is
[`validation/sglang-r8-tool-generation-qualification.json`](validation/sglang-r8-tool-generation-qualification.json).
The underlying r7 runtime provenance remains recorded in
[`validation/sglang-r7-gb10.json`](validation/sglang-r7-gb10.json).

## r8 scope and validation

This branch is the SGLang counterpart to the vLLM recipe on `main`. It retains
the same model revision, two-node RoCE topology, 270,000-token request limit,
four-request ordinary-chat concurrency, FP8 E4M3 KV cache, and DSpark
speculative decoding while using SGLang-specific kernels and scheduling.

The image uses DSpark block size 5, which gives the checkpoint's fixed
six-token verify window. Compact verification reads the measured
`runtime/dspark_sps_r6_profile.json` cost table. The adaptive FP8 WO-A path
uses checkpoint FP8 attention-projection weights for decode and verify, while
retaining BF16 weights for large prefill batches. Fused mHC pre-normalization
uses TileLang where qualified and falls back to DeepGEMM or Torch by shape.

The r7 SGLang tree bounds each request's sliding-window KV retention. Once the
configured SWA pool fills, every DSpark decode step evicts tokens outside the
model's active window before scheduling the next step; a single request can no
longer exhaust the pool merely by generating beyond its SWA allocation.

The qualified profile exposes `1,113,832` maximum total tokens and SGLang
reported `1,113,600` available KV tokens across both ranks. This is aggregate
concurrent capacity, not a one-million-token per-request context window.

r8 adds a writer-preferring generation gate around OpenAI chat requests. A
tool-bearing request runs exclusively against all other chat generation;
ordinary requests continue to share the four-request lane. This avoids the
reproduced DSV4 batch-corruption path without reducing long-context capacity or
ordinary concurrent throughput. Set `EXCLUSIVE_TOOL_GENERATION=0` only to
reproduce or diagnose the upstream defect.

### Measured comparison with the retained vLLM profile

| Workload | vLLM | SGLang r7 | SGLang r8 |
|---|---:|---:|---:|
| Physical DSpark round | 67.69 ms | 67.52 ms | unchanged |
| C4 sustained decode, concurrency 4 | 81.46 tok/s | 86.99 tok/s | unchanged |
| 127,900-token exact retrieval | 1,941 prompt tok/s | 2,085 prompt tok/s | unchanged |
| Fresh 8,192-token C1 Tetris generation | 64.90 tok/s | 58.75 tok/s median | 58.20 tok/s |
| Exact concurrency-eight tool-call validity | 64/64 | 117/128 | **192/192** |

The gated candidate passed two complete 64-request tool-call stress runs; the
published image passed a third. All 192 calls used the expected function,
decoded as JSON, matched every requested argument exactly, and ended with the
correct protocol finish reason. Four concurrent streaming tool calls also
passed while the engine metric remained at one running request.

The gate does not globally serialize the service. Four simultaneous ordinary
512-token chat generations reached `sglang:num_running_reqs=4` and completed
in 21.383 seconds versus 79.178 seconds of summed request latency. The
8,192-token Tetris workload measured 58.20 output tok/s, 0.94% below the r7
three-sample median. Concurrent tool-bearing chat requests intentionally queue;
this is the correctness cost until the upstream DSV4 batching defect is fixed.

## Requirements

- Exactly two NVIDIA DGX Spark systems.
- NVIDIA Container Toolkit and Docker Compose v2 on both systems.
- A working high-speed node-to-node fabric; the qualified deployment used RoCE.
- The same model snapshot at the same absolute path on both nodes.
- At least 2 GB of writable cache space per node for JIT artifacts.
- Access to `ghcr.io/liquidgravityai` for pulling the public image.

## 1. Download the model on both nodes

Install the Hugging Face CLI and download the pinned snapshot to a local path:

```bash
python3 -m pip install --user -U huggingface_hub
hf download deepseek-ai/DeepSeek-V4-Flash-0731 \
  --revision 9e165c30e2704aec5d9d593cce3eebd58bbef1cb \
  --local-dir /data/models/DeepSeek-V4-Flash-0731
```

Repeat on both Sparks. Do not point one rank at a different revision.

## 2. Identify the high-speed fabric settings

Run on each Spark:

```bash
ip -br address
ibdev2netdev
show_gids
```

Choose:

- `MASTER_ADDR`: rank 0's RoCE address.
- `FABRIC_IFACE`: the Linux interface carrying that address.
- `IB_HCA`: the matching RDMA device.
- `IB_GID_INDEX`: the GID table index for the chosen address.

The API may be accessed through a separate management interface; distributed
initialization must use the high-speed fabric.

## 3. Configure each node

Clone this repository and switch to the SGLang branch on both nodes:

```bash
git clone https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731.git
cd 2x-dgx-spark-deepseek-v4-flash-0731
git switch sglang
cp .env.example .env
```

Create the main and FlashInfer autotune cache directories:

```bash
mkdir -p \\
  /data/cache/deepseek-v4-flash-0731-sglang \\
  /data/cache/deepseek-v4-flash-0731-sglang-root
```

Fill every required value in `.env`. Both nodes use the same `MASTER_ADDR`,
model path, and fabric device names. Rank 0 uses `NODE_RANK=0`; rank 1 uses
`NODE_RANK=1`.

### Known-working `.env` shape

Rank 0:

```dotenv
NODE_RANK=0
MASTER_ADDR=169.254.97.143
FABRIC_IFACE=enp1s0f0np0
IB_HCA=rocep1s0f0
IB_GID_INDEX=3
MODEL_HOST_PATH=/data/models/DeepSeek-V4-Flash-0731
CACHE_HOST_PATH=/data/cache/deepseek-v4-flash-0731-sglang
```

Rank 1 changes only `NODE_RANK=1`; it still points `MASTER_ADDR` at rank 0.
Replace the example address and device names for your fabric.

## 4. Pull and start

Start rank 1 first:

```bash
# On rank 1 / worker
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

Then start rank 0:

```bash
# On rank 0 / API node
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

Follow rank-0 startup:

```bash
docker compose --env-file .env logs -f
```

The API is ready after SGLang prints:

```text
The server is fired up and ready to roll
```

The first start may spend substantial time compiling SM121-specific kernels.
The cache mounts preserve those artifacts across container recreation.

## 5. Verify the service

On rank 0:

```bash
curl -fsS http://127.0.0.1:8000/health
curl -fsS http://127.0.0.1:8000/v1/models
curl -fsS http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "deepseek-v4-flash-0731",
    "messages": [{"role": "user", "content": "Reply exactly SPARKINFER_OK"}],
    "temperature": 0,
    "max_tokens": 32
  }'
```

Confirm the response content is `SPARKINFER_OK`, then confirm both containers
remain healthy:

```bash
docker inspect deepseek-v4-flash-0731-sglang-0 \
  --format 'status={{.State.Status}} restarts={{.RestartCount}} oom={{.State.OOMKilled}}'
```

Run the same inspect command with suffix `-1` on rank 1.

## Required deployment knobs

Compose refuses to start while any of these are empty:

| Variable | Meaning |
|---|---|
| `NODE_RANK` | `0` on the API node, `1` on the worker |
| `MASTER_ADDR` | Rank-0 high-speed fabric address |
| `FABRIC_IFACE` | Linux high-speed interface |
| `IB_HCA` | RDMA device name |
| `IB_GID_INDEX` | GID index matching the selected RoCE address |
| `MODEL_HOST_PATH` | Absolute path to the pinned model snapshot |
| `CACHE_HOST_PATH` | Absolute writable cache directory |

`ROOT_CACHE_HOST_PATH` optionally overrides the FlashInfer autotune cache. It
defaults to `${CACHE_HOST_PATH}-root`.

## Performance and capacity knobs

The defaults are the qualified profile. Change one variable at a time and
re-run representative quality, concurrency, long-context, and stability tests.

| Variable | Default | Purpose |
|---|---:|---|
| `MAX_MODEL_LEN` | `270000` | Maximum context per request |
| `MAX_TOTAL_TOKENS` | `1113832` | Aggregate token budget across both ranks |
| `MAX_NUM_SEQS` | `4` | Maximum running ordinary chat requests |
| `EXCLUSIVE_TOOL_GENERATION` | `1` | Run tool-bearing chat requests exclusively; required for r8 correctness |
| `CHUNKED_PREFILL_SIZE` | `8192` | Chunked-prefill size |
| `MAX_PREFILL_TOKENS` | `16384` | Maximum prefill batch |
| `MEM_FRACTION_STATIC` | `0.82` | Static memory fraction |
| `MOE_RUNNER_BACKEND` | `flashinfer_mxfp4` | Qualified MXFP4 expert backend; Marlin was slower without improving tool accuracy |
| `DSPARK_BLOCK_SIZE` | `5` | DSpark draft block; six-token verify window |
| `RAGGED_VERIFY_MODE` | `compact` | Profiled compact verification |
| `SWA_FULL_TOKENS_RATIO` | `0.1` | SWA KV allocation fraction; r7 evicts out-of-window tokens |
| `CUDA_DEVICE_MAX_CONNECTIONS` | `1` | Qualified launch scheduling |

Do not set DSpark block size 6 with this checkpoint. Gamma 6 produced the
invalid CUDA-graph capture shape `[4, 5, -1]` against its fixed gamma-5
confidence head. A profiled gamma 7 candidate was also rejected: compact mode
failed CUDA-graph capture, while static mode reduced C1/C4 decode throughput by
11.8%/22.7% and the 8,192-token Tetris workload by 16.7%.

The FP4 DeepGEMM indexer is intentionally disabled. It improved the measured
128K prefill rate by 3.8%, but reduced C1/C4 decode by 1.9%/2.4% and the
8,192-token Tetris workload by 8.9%.

## Security and operational notes

The qualified runtime uses host networking, host IPC, `/dev/infiniband`,
`SYS_PTRACE`, and `seccomp=unconfined`. These are broad privileges. Run only on
trusted hosts and networks. The API has no authentication or TLS; place it
behind an authenticated reverse proxy before exposing it beyond the trusted
fabric.

Model loading is offline (`HF_HUB_OFFLINE=1`). The model directory is mounted
read-only. Cache directories are writable and should not be shared between
untrusted users.

## Troubleshooting

- **A required variable is missing:** copy `.env.example` and fill every blank
  required value.
- **Ranks cannot rendezvous:** verify both nodes use rank 0's RoCE address and
  `MASTER_PORT=20000`, and that the port is reachable over `FABRIC_IFACE`.
- **NCCL cannot select a device:** re-check `IB_HCA`, `IB_GID_INDEX`, and
  `FABRIC_IFACE` with `ibdev2netdev` and `show_gids`.
- **Startup recompiles kernels:** verify both cache mounts are writable and
  persistent.
- **CUDA graph capture fails after tuning:** restore `DSPARK_BLOCK_SIZE=5`,
  `MAX_NUM_SEQS=4`, and `CUDA_GRAPH_MAX_BS=4`.
- **Throughput differs materially:** the SPS table is hardware-, topology-,
  block-size-, and verify-mode-specific. Re-profile rather than copying it to a
  different configuration.

## Rebuilding the release layer

Deployment users should pull the published GHCR image. The included
`Dockerfile` embeds the qualified SPS table, entrypoint, exclusive
tool-generation source patch, and OCI provenance on top of the validated local
SGLang base.

```bash
BASE_IMAGE=spark-sglang:ds4-0731-d2c405f-sm121-cu132-swa-r7
IMAGE=ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r8-sglang-d2c405f-toolgate-flashinfer-67f7637-cu132

docker build \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  --build-arg IMAGE_CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg IMAGE_REVISION="$(git rev-parse HEAD)" \
  --tag "$IMAGE" \
  .
```

The qualified base image ID, final source trees, patch digests, published r8
manifest digest, and qualification measurements are recorded in
`validation/sglang-r8-tool-generation-qualification.json` and the underlying
`validation/sglang-r7-gb10.json` provenance receipt.

## Provenance

The runtime is derived from the Apache-2.0-licensed
[`sgl-project/sglang`](https://github.com/sgl-project/sglang), with FlashInfer,
SGL-Kernel, B12X, DeepGEMM, TileLang, and CUTLASS components under their
respective licenses. Repository content is released under Apache-2.0; see
[`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
