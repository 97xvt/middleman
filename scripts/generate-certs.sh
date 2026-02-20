#!/bin/sh
set -eu

CERT_DIR="${CERT_DIR:-/work/certs}"
CERT_FILE="${CERT_FILE:-localhost-cert.pem}"
KEY_FILE="${KEY_FILE:-localhost-key.pem}"
DAYS="${DAYS:-825}"
FORCE="${FORCE:-0}"

CERT_PATH="${CERT_DIR}/${CERT_FILE}"
KEY_PATH="${CERT_DIR}/${KEY_FILE}"

mkdir -p "${CERT_DIR}"

if [ "${FORCE}" != "1" ] && [ -f "${CERT_PATH}" ] && [ -f "${KEY_PATH}" ]; then
  echo "TLS certs already exist:"
  echo "- ${CERT_PATH}"
  echo "- ${KEY_PATH}"
  echo "Set FORCE=1 to regenerate."
  exit 0
fi

if [ "${FORCE}" = "1" ]; then
  rm -f "${CERT_PATH}" "${KEY_PATH}"
fi

apk add --no-cache openssl >/dev/null

openssl req \
  -x509 \
  -newkey rsa:2048 \
  -sha256 \
  -days "${DAYS}" \
  -nodes \
  -keyout "${KEY_PATH}" \
  -out "${CERT_PATH}" \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "Generated TLS certs:"
echo "- ${CERT_PATH}"
echo "- ${KEY_PATH}"
echo "Note: these are self-signed certificates."
