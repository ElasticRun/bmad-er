# lets-b-mad E2E (shuru)

End-to-end developer onboarding tests run inside an ephemeral [shuru](https://shuru.run/) Linux VM.

## One-time: create the prerequisites checkpoint

Shuru stores checkpoints on your machine (not in git — `checkpoint push` is not yet available). The repository ships the **bootstrap recipe**; each developer/CI agent runs this once:

```sh
tests/e2e/create-shuru-checkpoint.sh
```

That runs:

```sh
shuru checkpoint create lets-b-mad-linux-prereqs --allow-net -- \
  sh /e2e/shuru-bootstrap-prereqs.sh
```

Pre-installed in the checkpoint (see `shuru-bootstrap-prereqs.sh`):

- apt: `git`, `curl`, `nodejs`, `npm`, `python3`, `build-essential`, `wget`
- pinned: `jq` 1.8.1, `yq` 4.53.2, `uv` under `/usr/local/bin`

## Run tests

```sh
tests/e2e/run-developer-onboarding-shuru.sh
```

Uses `shuru run --from lets-b-mad-linux-prereqs` when the checkpoint exists; otherwise boots a fresh VM and prints a warning (slow path installs prereqs inline).

## Files

| File | Role |
| --- | --- |
| `shuru-bootstrap-prereqs.sh` | Apt + pinned tools; baked into checkpoint |
| `shuru-checkpoint.name` | Checkpoint name (`lets-b-mad-linux-prereqs`) |
| `create-shuru-checkpoint.sh` | Host script to build the checkpoint |
| `developer-onboarding-vm.sh` | In-VM test steps (clone, workspace, install, validate) |
| `run-developer-onboarding-shuru.sh` | Host wrapper (`--from` + mount `/e2e`) |
