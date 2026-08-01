ARG BASE_IMAGE=spark-vllm:ds4-0731-e63a190-sparkinfer-b0976b7-cu132
FROM ${BASE_IMAGE}

ARG IMAGE_CREATED
ARG IMAGE_REVISION

USER root

COPY runtime/serve-ds4-flash-spark.sh /opt/vllm-src/serve-ds4-flash-spark.sh
COPY runtime/entrypoint.sh /usr/local/bin/deepseek-v4-flash-2x-spark-entrypoint

RUN chmod 0755 \
      /opt/vllm-src/serve-ds4-flash-spark.sh \
      /usr/local/bin/deepseek-v4-flash-2x-spark-entrypoint \
 && rm -f /usr/local/bin/ds4-gilded-gnosis-entrypoint

LABEL org.opencontainers.image.title="DeepSeek V4 Flash 0731 for 2x DGX Spark" \
      org.opencontainers.image.description="Pinned two-node vLLM runtime for DeepSeek V4 Flash 0731 on NVIDIA DGX Spark" \
      org.opencontainers.image.source="https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731" \
      org.opencontainers.image.documentation="https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731#readme" \
      org.opencontainers.image.url="https://github.com/liquidgravityai/2x-dgx-spark-deepseek-v4-flash-0731" \
      org.opencontainers.image.vendor="Liquid Gravity AI" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="0731-vllm-e63a190-sparkinfer-b0976b7-cu132" \
      local-inference.vllm.ref="e63a190ee1b48d051ccebce485de343dbe2b3505" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}"

ENTRYPOINT ["/usr/local/bin/deepseek-v4-flash-2x-spark-entrypoint"]
