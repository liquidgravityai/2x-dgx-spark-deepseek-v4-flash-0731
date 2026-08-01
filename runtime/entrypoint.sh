#!/usr/bin/env bash
# Run the pinned Spark launcher against the image's compiled vLLM wheel.
set -euo pipefail

launcher=/opt/vllm-src/serve-ds4-flash-spark.sh
runtime_launcher=/tmp/serve-ds4-flash-spark.sh

# Run from a neutral directory so the raw source checkout does not shadow the
# compiled vLLM wheel. Keep source-relative recipe and artifact paths intact.
cp "${launcher}" "${runtime_launcher}"

cudagraph_mode=${VLLM_CUDAGRAPH_MODE:-FULL_AND_PIECEWISE}
case "${cudagraph_mode}" in
  NONE|PIECEWISE|FULL|FULL_DECODE_ONLY|FULL_AND_PIECEWISE) ;;
  *)
    printf 'VLLM_CUDAGRAPH_MODE has unsupported value: %s\n' \
      "${cudagraph_mode}" >&2
    exit 2
    ;;
esac

sed -i \
  -e 's|cd "$(dirname "$0")"|script_dir=/opt/vllm-src\ncd /|' \
  -e 's|source tools/spark/versions.env|source "${script_dir}/tools/spark/versions.env"|' \
  -e 's|${PWD}/.venv/bin|${script_dir}/.venv/bin|' \
  -e 's|${PWD}/.spark-artifacts|${script_dir}/.spark-artifacts|' \
  -e 's|exec .venv/bin/python|exec "${script_dir}/.venv/bin/python"|' \
  -e "s|FULL_AND_PIECEWISE|${cudagraph_mode}|g" \
  "${runtime_launcher}"

exec "${runtime_launcher}" "$@"
