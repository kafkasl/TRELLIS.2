# TRELLIS.2 GCP L4 Runbook

## Goal

Run TRELLIS.2 on GCP L4 reproducibly, with all fixes captured in the fork and no HF token stored on the VM.

## Source of Truth

- Local repo: `/Users/pengren/go/github.com/microsoft/TRELLIS.2`
- Fork: `https://github.com/kafkasl/TRELLIS.2`
- VM: `trellis-demo`, project `gen-lang-client-0206455006`, zone `us-west1-a`
- VM repo path: `~/trellis.v2`
- VM venv path: `~/trellis-v2-venv`
- Use Mac tmux pane `trellis-ssh:0.0` as the persistent SSH connection.
- Do **not** use tmux inside the VM for this workflow; reconnect if SSH drops.

## Working Loop

1. **Fix locally and push**
   - Edit local repo.
   - Commit and push to `origin/main`.

2. **Validate on VM**
   - In `trellis-ssh:0.0`:
     ```bash
     cd ~/trellis.v2
     git pull --ff-only
     TRELLIS_VENV_DIR=~/trellis-v2-venv \
       MAX_JOBS=4 \
       TORCH_CUDA_ARCH_LIST=8.9 \
       bash scripts/setup_gcp_l4.sh 2>&1 | tee ~/trellis-v2-setup.log
     ```

3. **Explore failures on VM**
   - Inspect logs/imports in the VM.
   - Once root cause is clear, go back to step 1 and codify the fix in the repo.

## Current Important Fixes in Fork

- `setup.sh` initializes `o-voxel` submodule before building.
- Extension installs are rerunnable/idempotent via clone-or-update.
- `o-voxel` installs with `--no-deps` after `CuMesh`/`FlexGEMM` to avoid redundant rebuilds.
- Standard `pillow==12.2.0` is force-reinstalled instead of `pillow-simd` to avoid mixed PIL/WebP installs.
- `flash-attn==2.7.3` installs with `--no-build-isolation`.
- Torch stack includes matching `torch`, `torchvision`, and `torchaudio` 2.6.0/cu124.
- `scripts/setup_gcp_l4.sh` delegates to upstream `setup.sh` instead of the obsolete TRELLIS v1 stack.
- `scripts/run_gcp_demo.sh` uses TRELLIS.2 defaults: `flash_attn` + `flex_gemm`.

## HF Model Cache Without Token on VM

DINOv3 is gated:

- `facebook/dinov3-vitl16-pretrain-lvd1689m`

Download locally, where HF is already authenticated:

```bash
hf download facebook/dinov3-vitl16-pretrain-lvd1689m
hf download microsoft/TRELLIS.2-4B
```

Copy cache dirs to VM without copying HF credentials:

```bash
tar -C ~/.cache/huggingface -cf - \
  hub/models--facebook--dinov3-vitl16-pretrain-lvd1689m \
  hub/models--microsoft--TRELLIS.2-4B \
| gcloud compute ssh trellis-demo \
    --zone us-west1-a \
    --project gen-lang-client-0206455006 \
    --command='mkdir -p ~/.cache/huggingface && tar -C ~/.cache/huggingface -xf -'
```

## Run App

Prefer SSH with port forwarding in `trellis-ssh:0.0`:

```bash
gcloud compute ssh trellis-demo \
  --zone us-west1-a \
  --project gen-lang-client-0206455006 \
  -- -L 7860:localhost:7860
```

Then in the VM:

```bash
cd ~/trellis.v2
source ~/trellis-v2-venv/bin/activate
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
bash scripts/run_gcp_demo.sh
```

From Mac, verify:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:7860/
```

Expected: `200`.

## Cleanup From Earlier Attempts

If a VM-side tmux session exists from earlier, kill it before using the direct SSH-pane workflow:

```bash
tmux kill-session -t trellis-setup 2>/dev/null || true
```
