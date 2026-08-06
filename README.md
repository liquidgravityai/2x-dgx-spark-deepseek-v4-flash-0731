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
ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r6-sglang-d2c405f-flashinfer-67f7637-cu132
```

Published manifest digest:

```text
PENDING_PUBLICATION
```

Use the immutable tag for reproducible deployments. This SGLang branch does
not move the repository package's vLLM-oriented `latest` tag.

| Component | Pinned value |
|---|---|
| Architecture | Linux ARM64 / NVIDIA GB10 (SM 12.1a) |
| CUDA | 13.2 |
| Qualified base image ID | `sha256:b20aa35a5c1aba811b70239f9f9e5b5865d8a4ccad2d8efec9abf7c0226edaa9` |
| SGLang | `d2c405f19df918c542c6cea9b1ddd59880e1e888` |
| SGLang source tree | `b2b423131b41ef7ce4e458ac7384e49541c46ed6` |
| SGLang performance tree | `b845e816dc7ddd34413834dc7a5b46586b2f5f49` |
| SGLang final WO-A tree | `445a046ec440c761c8bfae7950bb18f379392f4b` |
| SGL-Kernel | `fdebc938f7f4d16fe6b9f55dcd9a767cf0899ea1` |
| FlashInfer | `67f76379a145f19793896394974e29e610cda912` |
| FlashInfer final tree | `d8567dec0ff48f11c0ab1d17a05e944d50e48f7a` |
| Model revision | `9e165c30e2704aec5d9d593cce3eebd58bbef1cb` |
| Topology | 2 nodes, 1 GB10 per node, tensor parallel size 2 |

The full machine-readable source, image, configuration, and measurement
receipt is [`validation/sglang-r6-gb10.json`](validation/sglang-r6-gb10.json).

## r6 scope and validation

This branch is the SGLang counterpart to the vLLM recipe on `main`. It retains
the same model revision, two-node RoCE topology, 270,000-token request limit,
four-request concurrency target, FP8 E4M3 KV cache, and DSpark speculative
decoding while using SGLang-specific kernels and scheduling.

The image uses DSpark block size 5, which gives the checkpoint's fixed
six-token verify window. Compact verification reads the measured
`runtime/dspark_sps_r6_profile.json` cost table. The adaptive FP8 WO-A path
uses checkpoint FP8 attention-projection weights for decode and verify, while
retaining BF16 weights for large prefill batches. Fused mHC pre-normalization
uses TileLang where qualified and falls back to DeepGEMM or Torch by shape.

The qualified profile exposes `1,113,832` maximum total tokens and SGLang
reported `1,113,600` available KV tokens across both ranks. This is aggregate
concurrent capacity, not a one-million-token per-request context window.

### Measured comparison with the retained vLLM profile

| Workload | vLLM | SGLang r6 | SGLang delta |
|---|---:|---:|---:|
| Physical DSpark round | 67.69 ms | 67.52 ms | 0.2% faster |
| C4 sustained decode, concurrency 4 | 81.46 tok/s | 86.83 tok/s | 6.6% faster |
| 127,900-token exact retrieval | 1,941 prompt tok/s | 2,085 prompt tok/s | 7.4% faster |
| 8,192-token C1 Tetris generation | 62.44 tok/s | 59.65 tok/s | 4.5% slower |

The retained SGLang service passed the canonical `SPARKINFER_OK` smoke request,
two repeated 127,900-token exact-retrieval requests, and the measured C4 and
Tetris workloads with both containers at zero restarts and zero OOM kills.
The SGLang profile has **not** completed the vLLM recipe's identical four-way
269,989-token ceiling test or equivalent structured-output/tool-call
qualification. It is a strong long-context and concurrent-serving alternative,
not a universal per-workload parity claim.

## Requirements

- Exactly two NVIDIA DGX Spark systems.
- NVIDIA Container Toolkit and Docker Compose v2 on both systems.
- A working high-speed node-to-node fabric; the qualified deployment used RoCE.
- The same model snapshot at the same absolute path on both nodes.
- Approximately 100 GB of writable cache space per node for JIT artifacts.
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

Create the cache directories:

```bash
mkdir -p /data/cache/deepseek-v4-flash-0731-sglang/sglang-root
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

## Performance and capacity knobs

The defaults are the qualified profile. Change one variable at a time and
re-run representative quality, concurrency, long-context, and stability tests.

| Variable | Default | Purpose |
|---|---:|---|
| `MAX_MODEL_LEN` | `270000` | Maximum context per request |
| `MAX_TOTAL_TOKENS` | `1113832` | Aggregate token budget across both ranks |
| `MAX_NUM_SEQS` | `4` | Maximum running requests |
| `CHUNKED_PREFILL_SIZE` | `8192` | Chunked-prefill size |
| `MAX_PREFILL_TOKENS` | `16384` | Maximum prefill batch |
| `MEM_FRACTION_STATIC` | `0.82` | Static memory fraction |
| `DSPARK_BLOCK_SIZE` | `5` | DSpark draft block; six-token verify window |
| `RAGGED_VERIFY_MODE` | `compact` | Profiled compact verification |
| `CUDA_DEVICE_MAX_CONNECTIONS` | `1` | Qualified launch scheduling |

Do not set DSpark block size 6 with this checkpoint. Gamma 6 produced the
invalid CUDA-graph capture shape `[4, 5, -1]` against its fixed gamma-5
confidence head.

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
`Dockerfile` is the same small, auditable release layer pattern used by the
vLLM branch: it embeds the qualified SPS table, entrypoint, and OCI provenance
on top of the validated local SGLang base.

```bash
BASE_IMAGE=spark-sglang:ds4-0731-d2c405f-sm121-cu132-ormandj-r6
IMAGE=ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:r6-sglang-d2c405f-flashinfer-67f7637-cu132

docker build \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  --build-arg IMAGE_CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg IMAGE_REVISION="$(git rev-parse HEAD)" \
  --tag "$IMAGE" \
  .
```

The qualified base image ID and every final source tree and patch digest are
recorded in `validation/sglang-r6-gb10.json` and as labels on the base image.

## Provenance

The runtime is derived from the Apache-2.0-licensed
[`sgl-project/sglang`](https://github.com/sgl-project/sglang), with FlashInfer,
SGL-Kernel, B12X, DeepGEMM, TileLang, and CUTLASS components under their
respective licenses. Repository content is released under Apache-2.0; see
[`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
