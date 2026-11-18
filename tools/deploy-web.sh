#!/usr/bin/env bash
# Publish build/web to Vercel (project vae-victis, https://vae-victis.vercel.app).
# Run tools/export-web.sh first. Needs the Vercel CLI login (npx vercel login).
set -euo pipefail
cd "$(dirname "$0")/.."
npx --yes vercel@latest deploy build/web --prod --yes --name vae-victis
