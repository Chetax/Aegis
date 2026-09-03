# Offline Fallback Model

LoRA fine-tune of a small quantized model (Phi-3-mini / Gemma-2B), trained
on synthetic Q&A generated from the rules dictionary. Stretch feature —
used only when the device has no connectivity.

- `training/` — fine-tuning scripts (Unsloth/QLoRA)
- `export/` — quantized model export for on-device use
