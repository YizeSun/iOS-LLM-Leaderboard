# Submit a Device Result

Use this guide when submitting a local model or runtime result from iPhone, iPad, or Mac.

## Steps

1. Choose a fixed model, runtime, prompt, and device.
2. Record model, runtime, OS, and device metadata.
3. Record raw measurements that are actually available.
4. Copy `templates/device-result-template.json`.
5. Fill in all fields you can verify.
6. Add notes for unavailable metrics instead of inventing values.
7. Open a pull request with the completed JSON and reproduction notes.

## Measurement Notes

Useful metrics include tokens per second, first token latency, peak memory usage, thermal observations, and battery or energy observations.

Qualitative observations are acceptable during the MVP stage when clearly labeled.
