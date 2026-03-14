# Dual Camera EVDK Project Guide

This repository is the Lattice reference design split into two FPGA projects:

- `Crosslink_DualCSI2toRaw10/`: receives both MIPI CSI-2 camera streams, converts RAW10, and merges them in `SDR_user_ctrl`.
- `ECP5_Raw10toParallel/`: receives the merged RAW10 stream, applies the image pipeline, and drives HDMI.

## Current data path

The active ECP5 processing chain is:

`RAW10toParallel.v`
-> `image_pipe.v`
-> `ab.v` (auto-brightness)
-> `debayer.v`
-> `color.v`
-> `gamma_correction.v`
-> `image_postprocess.v`
-> HDMI output

The merge between the two cameras already happens on the CrossLink side, so the cleanest place to add new image processing is on the ECP5 after debayering.

## Implemented extension

A new post-processing block was added in `ECP5_Raw10toParallel/source/image_postprocess.v`.

Supported compile-time modes:

- `0`: bypass
- `1`: grayscale
- `2`: binary threshold
- `3`: Sobel edge extraction

`image_pipe.v` currently sets:

```verilog
localparam [1:0] POST_PROCESS_MODE = 2'd3;
```

So the default synthesized result is an edge-detection demo that is immediately visible on HDMI.

## Why this is a good project baseline

- It is fully inside the ECP5 image path, so it matches the assignment requirement.
- It is stream-based and does not require external DDR.
- It gives a concrete processing block that can be demonstrated, measured, and documented.
- It is a realistic starting point for more advanced work such as morphology, filtering, feature extraction, or a lightweight CNN-style preprocessor.

## Recommended next steps

1. Rebuild and program both FPGA projects on the EVDK.
2. Verify that the HDMI output shows the Sobel edge map from the merged camera stream.
3. If needed, tune `EDGE_THRESHOLD` in `image_pipe.v` for the actual lighting conditions.
4. Once the baseline is stable, replace or extend `image_postprocess.v` with the supervisor-approved algorithm.

## About the Bambu tutorial

The notebook linked by the user is useful as an HLS workflow tutorial:

- [Bambu conference tutorial 2026](https://github.com/ferrandi/PandA-bambu/blob/dev/panda/documentation/bambu101/bambu_conference_tutorial_2026.ipynb)

It is helpful for exploring how to move a C/C++ kernel toward synthesizable RTL, but it is not specific to this Lattice ECP5 demo. In practice, the safest project path is:

1. validate the algorithm in plain RTL inside `image_postprocess.v`
2. use Bambu only if the chosen algorithm becomes large enough to justify HLS
3. integrate the generated module back into the same streaming interface

## Report structure

For the final written report, cover these sections:

1. Demo architecture and signal flow across CrossLink and ECP5.
2. Original Lattice pipeline and identified insertion point.
3. Implemented processing algorithm and hardware architecture.
4. Resource, timing, and latency discussion.
5. Experimental results with screenshots from HDMI output.
6. Limitations and future extensions, including any HLS/deep-learning direction.
