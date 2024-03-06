set -x
cd ./matlab_codes
date=$(date '+%Y-%m-%d-%H-%M-%S')
base_path='../../data_train/'
noise_type="poisson";
/home/tonielook/MATLAB/R2021b/bin/matlab \
    -nodisplay -nosplash -nodesktop \
    -r "base_path='${base_path}',noise_type='${noise_type}';trainset_gen;exit;" 
set +x