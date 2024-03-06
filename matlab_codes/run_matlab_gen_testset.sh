set -x
cd ./matlab_codes
nSources=(5 10 15 20 25 30 35 40 45)
# nSources=(5)
ntest=100
noise_type='poisson'
save_path_base='../../data_test'
for nSource in "${nSources[@]}"; do
    /home/tonielook/MATLAB/R2021b/bin/matlab \
        -nodisplay -nosplash -nodesktop \
        -r "nSource='${nSource}',N_test='${ntest}',noise_type='${noise_type}',save_path='${save_path_base}/test${nSource}';testset_gen;quit"
done
set +x
