# source /home/lingjia/.bashrc
# source activate deepstorm3d
set -x
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/
weights=(0_0_1)
for weight in "${weights[@]}"; do
log_comment=$"1e-5-D250"
nSources=('5' '10' '15' '20' '25' '30' '35' '40' '45')
name_time=$(date '+%Y-%m-%d-%H-%M-%S')
model_path='./trained_model/2024-02-27-11-48-50-lr0.001-bs16-D41-Ep200-nT9000-w0_0_1-forwardKL_klnc_mse3d-1.0-1000.0-LocNet/ckpt_best_loss'
log_name='./trained_model//'${name_time}'_'${log_comment}'_test.log'
printf "Name Time: ${name_time}\n" >> ${log_name}
printf "Model Path: ${model_path}\n" >> ${log_name}
printf "Log Comment: ${log_comment}\n" >> ${log_name}
for nSource in "${nSources[@]}"; do
    # python3 main.py     --train_or_test='test'  \
    #                     --gpu_number='0'  \
    #                     --H=96  \
    #                     --W=96  \
    #                     --zmin=-20  \
    #                     --zmax=20  \
    #                     --clear_dist=1  \
    #                     --D=41  \
    #                     --scaling_factor=800  \
    #                     --upsampling_factor=1  \
    #                     --model_use='LocNet'  \
    #                     --batch_size=16  \
    #                     --checkpoint_path=${model_path}  \
    #                     --data_path="../data_test/test${nSource}"  \
    #                     --save_path='../test_output'  \
    #                     --port='16026'  \
    #                     --weight='0_0_1'  \
    #                     --extra_loss='mse3d_klnc_forward'  \
    #                     --klnc_a=10  \
    #                     --cel0_mu=1  \
    #                     --log_comment=${log_comment}  \
    #                     >> ${log_name}
    nohup python3 main.py     --train_or_test='test'  \
                        --gpu_number='0'  \
                        --H=96  \
                        --W=96  \
                        --zmin=-20  \
                        --zmax=20  \
                        --clear_dist=1  \
                        --D=41  \
                        --scaling_factor=800  \
                        --upsampling_factor=1  \
                        --model_use='LocNet'  \
                        --batch_size=16  \
                        --checkpoint_path=${model_path}  \
                        --data_path="./data_test/test${nSource}"  \
                        --save_path='./test_output'  \
                        --port='16026'  \
                        --weight=$weight  \
                        --extra_loss='forwardKL_klnc_mse3d'  \
                        --klnc_a=1000  \
                        --cel0_mu=1  \
                        --log_comment=${log_comment}  \
                        >> ${log_name}
done
done
# cd ./matlab_codes
# pred_path=`echo $pwd ../../test_output/2023-02-09-15-07-28-*`
# date=$(date '+%Y-%m-%d-%H-%M-%S')
# /home/tonielook/MATLAB/R2021b/bin/matlab \
#     -nodisplay -nosplash -nodesktop \
#     -r "pred_path_base='${pred_path}';postpro;quit"

printf "End: `date`\n\n\n" >> ${log_name}
set +x