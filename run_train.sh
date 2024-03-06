#!/bin/bash
#SBATCH --job-name=nc
#SBATCH --nodes=1
#SBATCH --partition=gpu_7d1g
#SBATCH --qos=normal
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --time=2-00:00:00
#SBATCH --output=/home/ljdai2/scratch/scratch_rpsf/nonconvex_loss/sbatch_output/klnc_locnet_v2.out

# source /home/ljdai2/.bashrc
# conda activate deepstorm3d
set -x
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/
weights=(0_0_1)
for weight in "${weights[@]}"; do
    log_comment=$"PoissonL7b10FluxU_"${weight}
    name_time=$(date '+%Y-%m-%d-%H-%M-%S')
    log_name='./trained_model/'${name_time}_${log_comment}'_train.log'
    printf "Name Time: ${name_time}\nStart Time: `date`\nLog Comment: ${log_comment}\nweight: ${weight}\n" >> ${log_name}
    
    nohup python3 main.py     --train_or_test='train'  \
                        --name_time=${name_time}  \
                        --gpu_number='0' \
                        --num_im=10000  \
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
                        --initial_learning_rate=0.001  \
                        --lr_decay_per_epoch=3  \
                        --lr_decay_factor=0.5  \
                        --max_epoch=200  \
                        --save_epoch=10  \
                        --data_path='./data_train'  \
                        --save_path='./trained_model'  \
                        --port='16026'  \
                        --weight=$weight  \
                        --extra_loss='forwardKL_klnc_mse3d'  \
                        --cel0_mu=1  \
                        --klnc_a=1000 \
                        >> ${log_name}
    printf "End: `date`\n\n\n" >>${log_name}
log_comment=$"1e-5-D250"
nSources=('5' '10' '15' '20' '25' '30' '35' '40' '45')
model_path=`ls ./trained_model/${name_time}-*/ckpt_best_loss`
log_name='./trained_model/'${name_time}'_'${log_comment}'_test.log'
printf "Name Time: ${name_time}\n" >> ${log_name}
printf "Model Path: ${model_path}\n" >> ${log_name}
printf "Log Comment: ${log_comment}\n" >> ${log_name}
for nSource in "${nSources[@]}"; do
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
# cd ./matlab_codes
# pred_path=`echo $pwd ../../test_output/${name_time}-*`
# date=$(date '+%Y-%m-%d-%H-%M-%S')
# /home/tonielook/MATLAB/R2021b/bin/matlab \
#     -nodisplay -nosplash -nodesktop \
#     -r "pred_path_base='${pred_path}';postpro;quit"
# cd ..
done
set +x
                        # --weight='1_0_0_0'  \
                        # --extra_loss='mse3d_cel0_klnc_forward'  \
