ARG BASE_IMAGE=spark-sglang:ds4-0731-d2c405f-sm121-cu132-swa-r7
FROM ${BASE_IMAGE}
ARG BASE_IMAGE

ARG IMAGE_CREATED
ARG IMAGE_REVISION
ARG TOOL_GATE_PATCH_SHA256=6c3abff755b05c2d52554b79548df88bb0c54e7c652322d3cad31a99454710a8

USER root

COPY runtime/dspark_sps_r6_profile.json /etc/sglang/dspark_sps_r6_profile.json
COPY runtime/entrypoint.sh /usr/local/bin/deepseek-v4-flash-2x-spark-entrypoint
COPY patches/sglang-exclusive-tool-generation.patch /tmp/sglang-exclusive-tool-generation.patch

RUN chmod 0644 /etc/sglang/dspark_sps_r6_profile.json \
 && chmod 0755 /usr/local/bin/deepseek-v4-flash-2x-spark-entrypoint

RUN printf '%s  %s\n' "${TOOL_GATE_PATCH_SHA256}" /tmp/sglang-exclusive-tool-generation.patch \
    | sha256sum -c - \
 && cd /opt/sglang \
 && patch --batch --forward -p1 < /tmp/sglang-exclusive-tool-generation.patch \
 && rm /tmp/sglang-exclusive-tool-generation.patch

LABEL org.opencontainers.image.title="DeepSeek V4 Flash 0731 for 2x DGX Spark with SGLang" \
      org.opencontainers.image.description="Qualified two-node SGLang runtime with exclusive tool-call generation, bounded hybrid-SWA eviction, DSpark speculative decoding, and profiled compact verification for NVIDIA DGX Spark" \
      org.opencontainers.image.source="https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731/tree/sglang" \
      org.opencontainers.image.documentation="https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731/tree/sglang#readme" \
      org.opencontainers.image.url="https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731/tree/sglang" \
      org.opencontainers.image.vendor="Liquid Gravity AI" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="0731-r8-sglang-d2c405f-toolgate-flashinfer-67f7637-cu132" \
      org.opencontainers.image.base.name="${BASE_IMAGE}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      local-inference.sglang.exclusive_tool_generation.patch_sha256="${TOOL_GATE_PATCH_SHA256}"

ENTRYPOINT ["/usr/local/bin/deepseek-v4-flash-2x-spark-entrypoint"]
CMD ["python", "-m", "sglang.launch_server", "--help"]
