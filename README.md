# 2x DGX Spark Recipe for DeepSeek V4 Flash 0731

A pinned, tested two-node vLLM deployment for
[`deepseek-ai/DeepSeek-V4-Flash-0731`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731)
on two NVIDIA DGX Spark systems.

The container contains the ARM64/CUDA runtime, vLLM, B12X kernels, SparkInfer,
and the optimized DSpark speculative-decoding configuration. Model weights are
**not** included; mount the same model revision on both nodes.

## Published image

```text
ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:vllm-e63a190-sparkinfer-b0976b7-cu132
```

Published manifest digest:

```text
ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731@sha256:4a20904cffc5f2d80f753d65d78a143661ff494335dabba6c4658bb3662bf6ad
```

The immutable tag is recommended for reproducible deployments. `latest` points
to the same image at publication time.

| Component | Pinned value |
|---|---|
| Architecture | Linux ARM64 / NVIDIA GB10 (SM 12.1) |
| CUDA | 13.2 |
| vLLM | `e63a190ee1b48d051ccebce485de343dbe2b3505` |
| SparkInfer | `b0976b7fd46b5d34357a5f615822b86792676feb` |
| Model revision | `9e165c30e2704aec5d9d593cce3eebd58bbef1cb` |
| Topology | 2 nodes, tensor parallel size 2, DCP size 1 |

## Requirements

- Exactly two NVIDIA DGX Spark systems.
- NVIDIA Container Toolkit and Docker Compose v2 on both systems.
- A working high-speed RoCE path between the Sparks. Direct ConnectX-7 cabling
  or a correctly configured RoCE switch fabric can be used.
- `/dev/infiniband` present inside the host OS.
- The pinned model snapshot available locally on both nodes.
- Enough local storage for the image, model, and a persistent JIT cache.

The recipe does not configure host addresses, routes, RoCE, or firewall rules.
Those must already work before the containers start.

## 1. Download the model on both nodes

Install the Hugging Face CLI and download the pinned snapshot to a local path:

```bash
hf download deepseek-ai/DeepSeek-V4-Flash-0731 \
  --revision 9e165c30e2704aec5d9d593cce3eebd58bbef1cb \
  --local-dir /absolute/path/to/DeepSeek-V4-Flash-0731
```

Review and accept the model repository's license and usage terms. The model is
not redistributed by this project.

## 2. Identify the high-speed fabric settings

Run these on each Spark:

```bash
ip -brief link
rdma link
ibdev2netdev
show_gids
```

Command availability varies by DGX OS release. Determine:

1. The Linux interface carrying node-to-node traffic.
2. This node's reachable address on that interface.
3. The RDMA/HCA device associated with that interface.
4. The GID index whose address matches the selected interface address.

Verify ordinary connectivity in both directions before testing RDMA/NCCL. The
rank-1 node must be able to reach rank 0 at `MASTER_ADDR`.

## 3. Configure each node

Clone this repository on both Sparks:

```bash
git clone https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731.git
cd 2x-dgx-spark-deepseek-v4-flash-0731
cp .env.example .env
```

Fill the required values in `.env`. The files differ only where noted:

| Variable | Rank 0 / API node | Rank 1 / worker node |
|---|---|---|
| `NODE_RANK` | `0` | `1` |
| `MASTER_ADDR` | rank 0 fabric address | same rank 0 fabric address |
| `VLLM_HOST_IP` | rank 0 fabric address | rank 1 fabric address |
| `FABRIC_IFACE` | local high-speed interface | local high-speed interface |
| `IB_HCA` | local RDMA device | local RDMA device |
| `IB_GID_INDEX` | matching local GID index | matching local GID index |
| `MODEL_HOST_PATH` | local model directory | local model directory |
| `CACHE_HOST_PATH` | local writable cache | local writable cache |

Create the cache directory on both systems:

```bash
mkdir -p /absolute/path/to/deepseek-v4-flash-cache
```

`MODEL_HOST_PATH` and `CACHE_HOST_PATH` must be absolute host paths. They may
differ between nodes.

Validate interpolation before starting:

```bash
docker compose --env-file .env config --quiet
```

## 4. Pull and start

Pull on both nodes:

```bash
docker compose --env-file .env pull
```

Start rank 1 first:

```bash
# On rank 1
docker compose --env-file .env up -d
```

Then start rank 0:

```bash
# On rank 0
docker compose --env-file .env up -d
```

Model loading, compilation, and first-use kernel/JIT caching take time. Follow
rank 0 until the API starts:

```bash
docker compose --env-file .env logs -f
```

The OpenAI-compatible API is exposed by rank 0 through host networking at
`API_PORT` (default `8000`).

```bash
curl --fail http://<rank-0-api-host>:8000/health
curl http://<rank-0-api-host>:8000/v1/models
```

Example request:

```bash
curl http://<rank-0-api-host>:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "deepseek-v4-flash-0731",
    "messages": [{"role": "user", "content": "Explain RoCE in one paragraph."}],
    "temperature": 0.2,
    "max_tokens": 256
  }'
```

Stop rank 0 first, then rank 1:

```bash
docker compose --env-file .env down
```

## Required deployment knobs

These have no portable defaults and Compose refuses to start while any are
empty:

| Variable | Meaning | How to choose it |
|---|---|---|
| `NODE_RANK` | Distributed rank | `0` for API/head, `1` for worker |
| `MASTER_ADDR` | Torch rendezvous endpoint | Rank 0 address on the selected high-speed fabric |
| `VLLM_HOST_IP` | Local distributed address | This node's address on that same fabric |
| `FABRIC_IFACE` | Linux network interface | Interface that owns `VLLM_HOST_IP` |
| `IB_HCA` | NCCL RDMA device | Device mapped to `FABRIC_IFACE`; comma-separated values are allowed |
| `IB_GID_INDEX` | RoCE GID selection | Index whose GID/address corresponds to `VLLM_HOST_IP` |
| `MODEL_HOST_PATH` | Model bind mount | Absolute path to the pinned snapshot |
| `CACHE_HOST_PATH` | Persistent cache bind mount | Absolute writable path, preferably fast local storage |

Incorrect interface, HCA, address, or GID selections commonly appear as an
NCCL timeout rather than a configuration error.

## Performance and capacity knobs

The defaults are the validated profile. Change one variable at a time and
re-run representative quality, concurrency, long-context, and stability tests.

| Variable | Validated default | Effect / constraint |
|---|---:|---|
| `GPU_MEMORY_UTILIZATION` | `0.82` | Higher values increase KV capacity but reduce headroom for graphs and JIT kernels. |
| `MAX_MODEL_LEN` | `262144` | Maximum request length. Reducing it does not by itself reserve more KV memory. |
| `MAX_NUM_BATCHED_TOKENS` | `4096` | Scheduler token budget. Larger values may improve prefill throughput but increase pressure and variability. |
| `MAX_NUM_SEQS` | `4` | Maximum concurrent sequences. Keep graph capture and memory headroom in mind. |
| `NUM_SPECULATIVE_TOKENS` | `6` | Fixed DSpark proposal depth. This model requires at least its five-token DSpark block size. |
| `DSPARK_DRAFT_SAMPLE_METHOD` | `greedy` | `greedy` is the published decode winner; `probabilistic` is the reference behavior. |
| `DSPARK_SPS_CURVE` | `auto` | Enables confidence/cost-based pruning of draft positions. |
| `ENABLE_PREFIX_CACHING` | `0` | Enable only for workloads with reusable prefixes, then re-measure memory and latency. |
| `API_PORT` | `8000` | Rank-0 HTTP port under host networking. |
| `MASTER_PORT` | `29501` | Distributed rendezvous port; must match on both nodes. |
| `SHM_SIZE` | `64g` | Container shared-memory declaration; host IPC is also enabled. |
| `NCCL_DEBUG` | `WARN` | Use `INFO` temporarily while diagnosing fabric setup. |

Keep these invariants for this published recipe:

- `NNODES=2`, `TP_SIZE=2`, and `DCP_SIZE=1`.
- `VLLM_DSPARK_DYNAMIC_DRAFT_DEPTH=0`.
- `VLLM_DSPARK_FP8_DRAFT_HEAD=0`.
- `ENABLE_FLASHINFER_AUTOTUNE=0`; this pinned build was qualified with its
  retained cache and autotuning disabled.
- `NCCL_CUMEM_ENABLE=0`.
- The model revision shown above. Other revisions are unqualified.

`VLLM_DSPARK_CAPACITY_ACTIVATION_BATCH_SIZE=0` means capacity-aware pruning is
active at every batch size; zero does not disable it.

## Measured profile

The retained profile was compared against fixed-K6 probabilistic drafting over
prompt length 2,048, generated length 128, context depth 0/8K, and concurrency
1/2/4. Ten measured batches were run in every cell (140 requests per profile).

| Metric, six-cell mean | Reference | Published profile | Change |
|---|---:|---:|---:|
| Per-request decode | 26.526 tok/s | 29.766 tok/s | **+12.22%** |
| Aggregate decode | 39.862 tok/s | 43.334 tok/s | +8.71% |
| Prefill | 2068.76 tok/s | 1978.22 tok/s | -4.38% |
| End-to-end TTFT | 5.182 s | 5.301 s | +2.29% |

The geometric mean of the six per-request decode speed ratios was +10.82%.
The profile primarily improves C1/C2 decode; aggregate throughput at C4 was
already saturated. A separate 8K-context, 512-token stability run completed at
C1/C2/C4, and both final suites passed coherence checks.

## Security and operational notes

The validated runtime uses host networking, host IPC, `/dev/infiniband`,
`SYS_PTRACE`, and `seccomp=unconfined`. These are broad privileges. Run only on
trusted hosts and review the Compose file against your security policy.

The image is ARM64 and DGX-Spark-specific. It is not an x86 image and is not a
generic CUDA image for other GPU architectures.

The service is intentionally not configured with authentication or TLS. Put an
authenticating reverse proxy in front of rank 0 before exposing the API beyond
a trusted network.

## Troubleshooting

- **Compose reports a required variable is missing:** fill every required entry
  in `.env`; empty values are treated as missing.
- **Rank 0 waits forever for rank 1:** check `MASTER_ADDR`, `MASTER_PORT`, host
  routing, and start order.
- **NCCL timeout or connection error:** verify `FABRIC_IFACE`, `IB_HCA`,
  `IB_GID_INDEX`, the address assigned to the interface, and any firewall.
- **Container cannot open `/dev/infiniband`:** install/enable the host RDMA
  stack and verify the device exists before starting Docker.
- **CUDA OOM during startup:** restore the validated memory settings and clear
  only experimental cache entries; do not delete a working shared cache while
  the service is running.
- **Slow first launch:** inspect logs before restarting. Compilation and cache
  population are expected; repeated forced restarts discard progress.

## Rebuilding the release layer

Deployment users should pull the published GHCR image. The included
`Dockerfile` is the small, auditable release layer that installs the generic
launcher, removes the internal entrypoint name, and sets public OCI metadata.
It expects the pinned compiled runtime image to exist locally:

```bash
docker build \
  --build-arg BASE_IMAGE=spark-vllm:ds4-0731-e63a190-sparkinfer-b0976b7-cu132 \
  --build-arg IMAGE_CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg IMAGE_REVISION="$(git rev-parse HEAD)" \
  -t ghcr.io/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731:local .
```

This Dockerfile is not a from-scratch vLLM compiler; rebuilding the large
compiled base remains a maintainer workflow. Runtime source commit labels are
preserved in the published image for provenance.

## Provenance

The runtime is derived from the Apache-2.0-licensed
[`local-inference-lab/vllm`](https://github.com/local-inference-lab/vllm) and
[`local-inference-lab/sparkinfer`](https://github.com/local-inference-lab/sparkinfer)
commits listed above. The container retains their source and license material.
DeepSeek model weights are separate and remain governed by the model
repository's terms.
