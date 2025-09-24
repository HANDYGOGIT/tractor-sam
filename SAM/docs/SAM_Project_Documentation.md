## Segment Anything (SAM) – Project Documentation

Generated: 2025-09-24
Audience: Project Manager, Software/ML Engineer

---

### 1. Executive Summary

The project integrates Meta AI's Segment Anything Model (SAM) to enable promptable image segmentation. It includes:
- Python package code for building and running SAM models, utilities, and example notebooks
- A simple React + TypeScript web demo that runs the exported ONNX mask decoder in the browser
- CLI scripts and utilities for automatic mask generation and ONNX export
- Example output artifacts under `output_dir/`

Key outcomes:
- Generate accurate object masks from input prompts (points/boxes) or automatically for all objects
- Export and run the lightweight mask decoder in ONNX, including in-browser inference
- Provide examples, demo UI, and scripts for quick adoption

---

### 2. Scope & Objectives

- Integrate core SAM components for promptable segmentation
- Provide automatic mask generation capability
- Support ONNX export for portable inference; demonstrate a browser-based demo
- Supply runnable notebooks for exploratory use and reproducibility

Out of scope:
- Large-scale training or dataset tooling beyond examples
- Production deployment infrastructure

---

### 3. Repository Structure (high level)

- `segment_anything/` – Python library (modeling, predictor API, utilities)
- `scripts/` – CLI utilities (automatic mask generation, ONNX export)
- `notebooks/` – Example Jupyter notebooks (predictor, automatic mask generator, ONNX)
- `segment-anything/demo/` – React + TypeScript web demo for ONNX in-browser inference
- `segment-anything/assets/` – Images and diagrams
- `output_dir/` – Example generated outputs (masks and overlays)

Relevant top-level docs:
- `segment-anything/README.md` – Installation, usage, ONNX export, checkpoints
- `segment-anything/demo/README.md` – Running the demo and structure

---

### 4. Architecture Overview

Conceptual flow:
1) Input image and optional prompts (points, boxes, masks)
2) Image encoded by vision transformer backbone
3) Prompts encoded by prompt encoder
4) Mask decoder outputs segmentation masks
5) Post-processing to produce binary masks and quality metrics

Components:
- Modeling (`segment_anything/modeling/`):
  - `sam.py` – Model assembly (image encoder, prompt encoder, mask decoder)
  - `image_encoder.py`, `prompt_encoder.py`, `mask_decoder.py`, `transformer.py`, `common.py`
- Predictor API (`segment_anything/predictor.py`):
  - `SamPredictor`: high-level interface to set images and generate masks from prompts
- Automatic Mask Generator (`segment_anything/automatic_mask_generator.py`):
  - `SamAutomaticMaskGenerator`: generates multiple masks per image automatically
- Utilities (`segment_anything/utils/`): transforms, ONNX helpers, AMG utilities
- CLI scripts (`scripts/`):
  - `amg.py` – command-line automatic mask generation
  - `export_onnx_model.py` – export mask decoder to ONNX
- Web demo (`segment-anything/demo/`):
  - Loads an image embedding and runs ONNX mask decoder in browser (WASM, workers, SIMD)

---

### 5. Installation & Setup

Prerequisites:
- Python >= 3.8, PyTorch >= 1.7, TorchVision >= 0.8 (CUDA recommended)
- Node.js >= 16 for running the demo

Install the Python package (editable):
```
cd segment-anything
pip install -e .
```

Optional dependencies for notebooks and ONNX:
```
pip install opencv-python pycocotools matplotlib onnxruntime onnx jupyter
```

---

### 6. Getting Started (Python)

Load a checkpoint and run with prompts:
```
from segment_anything import SamPredictor, sam_model_registry
sam = sam_model_registry["<model_type>"](checkpoint="<path/to/checkpoint>")
predictor = SamPredictor(sam)
predictor.set_image(<your_image>)
masks, scores, logits = predictor.predict(<input_prompts>)
```

Automatic mask generation:
```
from segment_anything import SamAutomaticMaskGenerator, sam_model_registry
sam = sam_model_registry["<model_type>"](checkpoint="<path/to/checkpoint>")
mask_generator = SamAutomaticMaskGenerator(sam)
masks = mask_generator.generate(<your_image>)
```

Command-line automatic mask generation:
```
python scripts/amg.py --checkpoint <path/to/checkpoint> \
  --model-type <model_type> --input <image_or_folder> --output <path/to/output>
```

Model types and checkpoints (from README):
- `default` or `vit_h`: ViT-H
- `vit_l`: ViT-L
- `vit_b`: ViT-B

---

### 7. ONNX Export and Web Demo

Export ONNX mask decoder:
```
python scripts/export_onnx_model.py --checkpoint <path/to/checkpoint> \
  --model-type <model_type> --output <path/to/output>
```

Run the browser demo:
```
cd segment-anything/demo
npm install --g yarn
yarn && yarn start
```
Then open http://localhost:8081/.

Demo inputs to update in `src/App.tsx`:
- `IMAGE_PATH`, `IMAGE_EMBEDDING`, `MODEL_DIR`

Notes on multithreading:
- Dev server headers enable `SharedArrayBuffer` via cross-origin isolation in `configs/webpack/dev.js`.

---

### 8. Data Flow Details

- Preprocessing: images are resized/normalized; longest side typically 1024 for the demo
- Prompt encoding: points, boxes, or masks converted into embeddings
- Image encoding: ViT backbone extracts image features
- Mask decoding: transformer-based head predicts masks conditioned on prompts
- Post-processing: thresholding, stability scoring, and quality metrics

---

### 9. Outputs and Artifacts

- `output_dir/mask/*.png` – Per-instance or per-region binary masks
- `output_dir/mask_overlay.png` – Composite overlay for quick visualization

---

### 10. Quality, Performance, and Risks

- Performance depends on backbone size and hardware (CPU vs GPU)
- Large images increase memory/time; tiling or downscaling may be necessary
- ONNX CPU inference is slower than GPU; in-browser uses WASM + SIMD where available
- Deterministic outputs for fixed prompts and seeds; beware of preprocessing differences

---

### 11. Roadmap Suggestions

- Provide Docker images for repeatable demos and notebooks
- Add CLI for interactive promptable segmentation (points/boxes) beyond AMG
- Integrate CI with linting, unit tests, and sample inference tests
- Add quantitative evaluation scripts (e.g., IoU, stability) and benchmarks

---

### 12. References

- Main README: `segment-anything/README.md`
- Demo README: `segment-anything/demo/README.md`
- Notebooks: `notebooks/*`
- Paper, demo, dataset links provided in `segment-anything/README.md`


