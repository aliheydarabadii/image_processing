# Dual CSI-2 Camera to HDMI Bridge Demo

This repository contains a Lattice Embedded Vision Development Kit (EVDK) reference design extended for an FPGA image-processing project.

The starting point is the vendor dual-camera demo:

- two MIPI CSI-2 cameras are captured on the CrossLink device
- the two RAW10 streams are merged
- the merged stream is sent to the ECP5
- the ECP5 performs image processing and drives the HDMI output

## Project goal

The goal of this project is to design and implement an FPGA-based image-processing application on the ECP5, starting from the provided dual-camera-to-HDMI demo design.

Student contact:

- Serena Curzel, `serena.curzel@polimi.it`

## Repository structure

- `Crosslink_DualCSI2toRaw10/`: MIPI CSI-2 reception, RAW10 unpacking, and dual-camera merge
- `ECP5_Raw10toParallel/`: RAW10 to RGB pipeline, image processing, and HDMI output
- `PROJECT_GUIDE.md`: implementation notes, architecture summary, and suggested report structure
- `ReadMe.txt`: original short vendor note bundled with the demo

## Current FPGA extension

A new ECP5 post-processing block has been added in:

- `ECP5_Raw10toParallel/source/image_postprocess.v`

It supports these compile-time modes:

- `0`: bypass
- `1`: grayscale
- `2`: threshold
- `3`: Sobel edge detection

The default configuration currently enables Sobel edge detection through:

```verilog
localparam [1:0] POST_PROCESS_MODE = 2'd3;
```

in `ECP5_Raw10toParallel/source/image_pipe.v`.

## Processing pipeline

The active ECP5 pipeline is:

`RAW10toParallel.v`
-> `image_pipe.v`
-> `ab.v`
-> `debayer.v`
-> `color.v`
-> `gamma_correction.v`
-> `image_postprocess.v`
-> HDMI

The important architectural detail is that the camera merge already happens on the CrossLink side, so new image-processing functions are best added in the ECP5 pipeline after debayering.

## Build and test

1. Open `Crosslink_DualCSI2toRaw10/` in the Lattice toolchain and rebuild/program the CrossLink design.
2. Open `ECP5_Raw10toParallel/` in Lattice Diamond and rebuild/program the ECP5 design.
3. Verify the HDMI output on the EVDK board.
4. If needed, tune the post-processing parameters in `ECP5_Raw10toParallel/source/image_pipe.v`.

## Bambu reference

The following tutorial can be useful if the project later moves toward HLS-based accelerator development:

- [Bambu conference tutorial 2026](https://github.com/ferrandi/PandA-bambu/blob/dev/panda/documentation/bambu101/bambu_conference_tutorial_2026.ipynb)

For this repository, the practical baseline is still the current streaming RTL implementation on the ECP5.

## Documentation

For a more detailed explanation of the architecture, extension strategy, and suggested final report sections, see:

- `PROJECT_GUIDE.md`
