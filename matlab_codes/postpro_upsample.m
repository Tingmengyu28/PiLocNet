% Post-process on original size LocNet output, e.g., 192*192*250

% Parameters from demo.py (Generating Data)
load('data_natural_order_A'); % Single role
global Np nSource L Nzones
L = 4; Nzones = 5; b = 5; [Nx,Ny,Nz] = size(A); Np = Nx;
zmax = 20;

% Parameters from LocNet
clear_dist = 1;
up_xy = 2; zgrid = 250; up_z = zgrid/(zmax*2+1+clear_dist*2);
bol_size = [Np*up_xy,Np*up_xy,zgrid];
xyr = 2*up_xy; zr = ceil(up_z);

% Path
pred_path_base = '/home/tonielook/rpsf/20221204_LocNet_LossTunning/test_output/2022-12-26-00-28-14-w1_0_0-mse3d_klnc_forward-1e-5-D250';
mat_path_base = '/home/tonielook/rpsf/20221204_LocNet_LossTunning/data_test';

% tag of visualization & save pred_label.csv & eval.csv
tag_view = 0;
tag_save = 1;

%% Loop for different densities
% nsources = [5,10,15,20,30,40,50,60];
nsources = [60];

% overall performance
infer_save = zeros(5,length(nsources));
if tag_save
    eval_all = fopen(fullfile(pred_path_base,'eval.csv'), 'w');
    eval_header = ["pts","recall","precision","jaccard index","f1 score","mean predict pts"];
    fprintf(eval_all, '%s,%s,%s,%s,%s,%s\n', eval_header);
end

for nsource_idx = 1:length(nsources)
    nSource = nsources(nsource_idx);

    % Read Ground-truth Label and Prediction
    pred_path = fullfile(pred_path_base,['test',num2str(nSource)]);
    if tag_view
        mat_path = fullfile(mat_path_base,['test',num2str(nSource)],'clean');
    end

    gt = readmatrix(fullfile(pred_path,'label.txt'));
    pred = readmatrix(fullfile(pred_path,'loc_bool_0.csv'));
%     pred = pred(:,2:6);

    % Index of images start from 1
    gt(:,1) = gt(:,1) - min(gt(:,1))+1;
    pred(:,1) = pred(:,1) - min(pred(:,1))+1;

    % Initialize Evaluation Metrics
    recall = zeros();
    precision = zeros();
    jaccard_index = zeros();
    f1_score = zeros();
    flux_all = [];
    num_pts = zeros();
    
    if tag_save
        save_path = pred_path;
        label = fopen(fullfile(save_path, ['pred_label_upsample_pt',num2str(nSource),'.csv']), 'w');
        label_header = ["index", "x", "y", "z", "flux","shift x","shift y","shift z","TP(1)orFP(0)"];
        fprintf(label, '%s,%s,%s,%s,%s,%s,%s,%s,%s\n', label_header);

        eval = fopen(fullfile(save_path, ['eval_upsample_pt',num2str(nSource),'.csv']), 'w');
        eval_header = ["index", "recall", "precision", "jaccard index", "f1 score","num pts"];
        fprintf(eval, '%s,%s,%s,%s,%s,%s\n', eval_header);
    end

    %% Loop for samples of a same zeta value
    tic
    for nt = 1:size(gt,1)/nSource
        gt_tmp = gt(gt(:,1)==nt,:);
        pred_tmp = pred(pred(:,1)==nt,:);

        if tag_view  % View Initial Prediction
            figure(1);
            plot3((gt_tmp(:,2)+Np/2)*up_xy,(gt_tmp(:,3)+Np/2)*up_xy,(gt_tmp(:,4)+zmax)*up_z,'ro', pred_tmp(:,2),pred_tmp(:,3),pred_tmp(:,4),'bx');
            title(sprintf('Image %d - Initial Prediction', nt));
            axis([0 bol_size(1) 0 bol_size(2) 0 bol_size(3)]); 
            grid on;
            pause(0.5)
        end

        % Load Ground Truth 3D Grid
        interest_reg = zeros((xyr*2+1)^2*(zr*2+1), nSource); 
        Vtrue = [(gt_tmp(:,2)+Np/2)*up_xy; (gt_tmp(:,3)+Np/2)*up_xy; (gt_tmp(:,4)+zmax)*up_z; gt_tmp(:,5)];
        flux_gt = gt_tmp(:,5);
        for i = 1 : nSource
            x0 = zeros(bol_size);
            xlow = floor(Vtrue(i));
            ylow = floor(Vtrue(i+nSource));
            zlow = floor(Vtrue(i+2*nSource));
            % lower bound
            rxl = max(1,xlow-xyr);
            ryl = max(1,ylow-xyr);
            rzl = max(1,zlow-zr);
            % upper bound
            rxu = min(96*up_xy, xlow+xyr);
            ryu = min(96*up_xy, ylow+xyr);
            rzu = min(zgrid, zlow+zr);
            % 
            x0(rxl:rxu, ryl:ryu, rzl:rzu) = Vtrue(i+3*nSource);
            gtpts = find(x0~=0);
            % fill in remainning parts with 0
            interest_reg(:,i) = [gtpts; zeros(size(interest_reg,1)-length(gtpts),1)];
        end

        % Load Initial Prediction
        Vpred = [pred_tmp(:,2);pred_tmp(:,3);pred_tmp(:,4);pred_tmp(:,5)];
        pred_vol = zeros(bol_size);
        nPred = length(Vpred)/4;
        for i = 1 : nPred
            xlow = max(Vpred(i),1); 
            ylow = max(Vpred(i+nPred),1);
            zlow = max(Vpred(i+2*nPred),1);
            pred_vol(xlow,ylow,zlow)= pred_vol(xlow,ylow,zlow)+Vpred(i+3*nPred);
        end

        % Removing Clustered False Positive
        [xIt, elx, ely, elz] = local_3Dmax_large_v2(pred_vol,xyr,zr);
        
        idx_est = find(xIt>0); 
        if isempty(idx_est)
            continue
        end
        
        flux_est = xIt(idx_est);

        % Refinment on Estimation of Flux
%         load(fullfile(mat_path,['im',num2str(nt),'.mat']));  % mat file for g
%         flux_est_var = Iter_flux(A, idx_est, g, b);        
        
        %% Evaluation
        num_gt = nSource; num_pred = length(idx_est);
        [num_tr,tp_pred,tp_gt,flux_total] = evaluation(xIt, interest_reg, flux_est, flux_gt);

        re = num_tr/num_gt;
        pr = num_tr/num_pred; 
        ji = num_tr/(num_gt + num_pred - num_tr);
        f1 = 2*(re*pr)/(re+pr);
        num_pt = numel(find(xIt>0));

        recall(nt) = re;
        precision(nt) = pr;
        jaccard_index(nt) = ji;
        f1_score(nt) = f1;
        num_pts(nt) = num_pt;

        fprintf('Image %d in %d point source case\n', nt,nSource)
        fprintf('TP = %d, Pred = %d, GT = %d\n',num_tr,num_pred,num_gt);    
        fprintf('Recall = %3.2f%%, Precision = %3.2f%%\n',recall(nt)*100,precision(nt)*100);
        fprintf('---\n');

        %% Save Results
        [xx,yy,zz] = ind2sub(bol_size, find(xIt>0)); 
        sx = zeros(length(xx),1);  sy = zeros(length(xx),1); sz = zeros(length(xx),1);
        for sidx = 1: length(xx)
            tx = xx(sidx); ty = yy(sidx); tz = zz(sidx);
            sx(sidx) = elx(tx, ty, tz);
            sy(sidx) = ely(tx, ty, tz);
            sz(sidx) = elz(tx, ty, tz);
        end

        tplist = zeros(num_pred,1);
        if ~isempty(tp_pred)
            tplist = max(find(xIt>0) - tp_pred==0,[],2);
        end

        % save pred_label{nSource}.csv & eval{nSource}.csv
        if tag_save
            LABEL = [nt*ones(1,length(xx))', xx, yy, zz, flux_total(2,:)', sx, sy, sz, tplist];
            fprintf(label, '%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d\n', LABEL');

            EVAL = [nt, re, pr, ji, f1, num_pt];
            fprintf(eval, '%d,%.4f,%.4f,%.4f,%.4f,%d\n', EVAL);
        end       
        
        if tag_view
            % View Final Prediction After Post-pro Integer Version
            load(fullfile(mat_path,['im',num2str(nt),'.mat']));
            tplist_gt = zeros(nSource,1);
            if ~isempty(tp_gt)
                tplist_gt = max([1:1:nSource]' - tp_gt == 0,[],2);
            end
            
            figure(3);
            plot3((gt_tmp(tplist_gt,2)+Np/2)*up_xy,(gt_tmp(tplist_gt,3)+Np/2)*up_xy,(gt_tmp(tplist_gt,4)+zmax)*up_z,'ro',...
                  (gt_tmp(tplist_gt==0,2)+Np/2)*up_xy,(gt_tmp(tplist_gt==0,3)+Np/2)*up_xy,(gt_tmp(tplist_gt==0,4)+zmax)*up_z,'r^',...
                  xx(tplist),yy(tplist),zz(tplist),'bx',...
                  xx(tplist==0),yy(tplist==0),zz(tplist==0),'b^')
            axis([0 Np*up_xy 0 Np*up_xy 0 zgrid]); 
            grid on;
            if num_tr<num_gt && num_tr<num_pred
                legend('TP-GT','FN-GT','TP-EST','FP-EST','Location','Southoutside','Orientation','horizontal')
            elseif num_tr<num_gt
                legend('TP-GT','FN-GT','TP-EST','Location','Southoutside','Orientation','horizontal')
            elseif num_tr<num_pred
                legend('TP-GT','TP-EST','FP-EST','Location','Southoutside','Orientation','horizontal')
            else    
                legend('TP-GT','TP-EST','Location','Southoutside','Orientation','horizontal')
            end
            title(sprintf('Image % d Result after postpro',nt))
            hold on; imagesc(imresize(I0,2)); hold off
            pause(0.5)

%             % View in size 96*96*41
%             figure(5);
%             plot3(gt_tmp(:,2)+49,gt_tmp(:,3)+49,gt_tmp(:,4)+20,'ro',...
%                 xxtp/up_xy,yytp/up_xy,zztp/up_z,'bx')
%             axis([0 96 0 96 0 42]); grid on
%             legend('GT','EST','Location','Southoutside','Orientation','horizontal')
%             title(sprintf('Image %d in Result after postpro in 96*96*41',nt))
%             pause(0.001)            

        end
    end
    %% Display Mean Evaluation Metrics
    mean_precision = mean(precision);
    mean_recall = mean(recall);
    mean_jaccard = mean(jaccard_index);
    mean_f1_score = mean(f1_score);
    mean_num_pts = mean(num_pts);

    fprintf('Total %d Images\n', size(gt,1)/nSource);
    fprintf('Recall=%.2f%%, Precision=%.2f%%, Jaccard=%.2f%%, F1 socre=%.2f%% \n',...
            mean_precision*100 ,mean_recall*100, mean_jaccard*100, mean_f1_score*100);
    toc

    end












