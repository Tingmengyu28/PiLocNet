#!/bin/sh
set -x
cd ./matlab_codes
pred_path='../../test_output/2023-01-03-21-52-09-w1_1_0-mse3d_klnc_forward-1e-5-D250'
date=$(date '+%Y-%m-%d-%H-%M-%S')
/home/tonielook/MATLAB/R2021b/bin/matlab \
    -nodisplay -nosplash -nodesktop \
    -r "pred_path_base='${pred_path}';postpro;quit"
set +x
