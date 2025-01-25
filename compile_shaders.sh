#!/bin/bash

for i in src/shaders/*.glsl; do
    ~/sokol-shdc -i $i -o $i.zig -l metal_macos:hlsl5:glsl300es:wgsl -f sokol_zig
done

