# RLM Configuration for Large Files

Use increased limits for 64MB+ files:

```toml
# config-large-files.toml
max_iterations = 50        # More iterations for complex queries
max_sub_calls = 100        # More sub-calls for detailed analysis
output_limit = 50000       # Larger output for full extractions

bypass_enabled = true
bypass_threshold = 4000

[wasm]
enabled = true
rust_wasm_enabled = true
fuel_limit = 5000000       # 5x normal for large files
memory_limit = 268435456   # 256MB for large context

codegen_provider = "ollama"
codegen_url = "http://192.168.1.120:11434"
codegen_model = "qwen2.5:14b-instruct-q4_K_M"

[[providers]]
provider_type = "ollama"
base_url = "http://192.168.1.120:11434"
model = "qwen2.5:14b-instruct-q4_K_M"
role = "root"
weight = 1

[[providers]]
provider_type = "ollama"
base_url = "http://192.168.1.120:11434"
model = "qwen3:1.7b-q4_K_M"
role = "sub"
weight = 1
```

**Usage:**

```bash
cd <RLM_PROJECT_DIR>
./rlm-server config-large-files.toml
```
