# Submit a Model Result

Use this guide when submitting a result for a benchmark task.

## Steps

1. Choose an existing task from `benchmarks/`.
2. Run the model with the task prompt.
3. Review the output using the documented scoring rubric.
4. Copy `templates/model-result-template.json`.
5. Fill in all required fields.
6. Place the completed JSON file in `results/raw/`.
7. Run `python3 scripts/validate_result.py results/raw/<file>.json`.
8. Open a pull request with the raw result and any relevant notes.

## Required Fields

- `model_name`
- `provider`
- `task_id`
- `score`
- `evaluator`
- `date`
- `notes`

Do not submit placeholder or fabricated results.
