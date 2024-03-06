clear 
close all
addpath('../input_data/');
addpath(genpath('../common_func'));


global   Np nSource L Nzones sigma
L = 4; Nzones = 7; nSource = 5;
N_test  = 1;
Noise_kind = 0; % 1 for poisson noise and 0 for gaussian noise 
method = 4; % 0 for omp, 1 for sbr; 2 for l1-admm % 3 for CEL0 4 for NC
load('data_natural_order_A');
[Nx,Ny,Nz] = size(A);
A_int = zeros(Nx,Ny,Nz,Nz);
    for i = 1:size(A,3)
        A_int(:,:,:,i)  = inner_prod(A(:,:,i),A);
    end
Np = Nx;
interest_reg = zeros(32,nSource);
time = zeros(N_test,1);
recall = zeros(N_test,1);
precision = zeros(N_test,1);
ab_error = time;
time_p = zeros(N_test,1);
recall_p = zeros(N_test,1);
precision_p = zeros(N_test,1);
ab_error_p = ab_error;

% for sbr 5 and 10 show 3D localization, we use 6
% for comparion with other algos, we use 45 for 10 pt

% for cel0 15, we use 6 and 30 for 33
% for comparion with other algos, we use 45 for 10 pt

for nt = N_test
    fprintf('Test %d\n',nt)
    rng(50*nt)
       
            real_pos = zeros(nSource, 3);
            
    %%-------------- small region--------------------
            Flux_true = poissrnd(2000,[1,nSource]);
            Xp_true = 34*2*(rand(1,nSource)-0.5); 
            Yp_true = 34*2*(rand(1,nSource)-0.5); 
            zeta_true = 2*20*(rand(1,nSource)-0.5); 
            Vtrue = [Xp_true Yp_true zeta_true Flux_true];
           [I0,flux] = PointSources_poisson_v2(nSource,Vtrue);
    %%---------------------------------------------
            for i = 1 : nSource
                x0 = zeros(size(A));
                xlow = floor(49+Vtrue(i)); 
                ylow = floor(49+Vtrue(i+ nSource));
                zlow = floor((Vtrue(i+2*nSource)+21)/2.1)+1;
                x0(xlow-1:xlow+2,ylow-1:ylow+2,zlow:zlow+1)= Vtrue(i+3*nSource); % large range
                interest_reg(:,i) = find(x0~=0);
            end
    switch Noise_kind
        case 0 % gaussian noise 
            sigma = max(I0(:))/10;
            g = I0 + sigma*randn(Np);
%             lambda = 800;
        case 1 % poisson noise 
            b = 5; g = poissrnd(I0+b)-b;
%             lambda = 800;
    end

tic

switch method 
    case 1
%% SBR
      if nSource == 5
          lambda = 800;
      elseif nSource == 10
          lambda = 1100;
      else
          lambda = 1200;
      end
     [idx_est,flux] =  SBR_acel_v4(g,A,A_int,lambda);
     %-------- remove negative flux------------
     idx_est = idx_est(flux>0);
     flux = flux(flux>0);
     %-------------------------------------------    
     time_p(nt) = toc;
     u1 = zeros(size(A));
     u1(idx_est) = flux;% x_est_p = fftshift(x_est_p,3);
    case 0    
 %% OMP
    if nSource == 5
        thd = 5;
    elseif nSource == 10
        thd = 6;
    elseif nSource == 15
        thd = 9;
    elseif nSource == 20
        thd = 14;
    else
        thd = 17;
    end
    [Pt_o, flux_o] =  OMP(g,A,thd); 
    u1 = zeros(size(A));
    for i = 1: size(Pt_o,2)%nSource
        u1(Pt_o(1,i)+Nx/2+1,Pt_o(2,i)+Ny/2+1,22-Pt_o(3,i)) = 1;
    end
    case 2
%% L1-ADMM    
    if nSource == 5 
        p1 = 0.0015; p2 =  400; p3 = 50.0000; 
    elseif nSource == 10
         p1 = 0.0015; p2 =  400; p3 = 50.0000; 
    elseif nSource == 20
        p1 = 0.0005; p2 =  700; p3 = 50.0000; 
    elseif nSource == 30
        p1 = 0.0005; p2 =  400; p3 = 60.0000;
    elseif nSource == 40
         p1 = 0.0005; p2 =  400; p3 = 60.0000; 
    else
       p1 = 0.0005; p2 =  500; p3 = 60.0000;   % 15,  point sources case
    end
    [u1] = ADMM_l2_l1(g, A,p1,p2,p3);    
    
    case 3
        if nSource == 5 || nSource == 10 || nSource == 20
            p1 = 0.0010; p2 = 5000; p3 = 40.0000; 
        elseif nSource == 15
            p1 = 0.0010; p2 = 5500; p3 = 40.0000;
        elseif nSource == 30 
            p1 = 0.0010; p2 = 3000; p3 = 40.0000;
        else
            p1 = 0.0010; p2 = 3500; p3 = 40.0000;
        end
        [u1] = CEL0_ADMM(g, A,p1,p2,p3);    
    case 4
         mu = 0.005;a = 10.0000; nu = 0.10;lambda = 160.0000; 
        [u1] = IRL1_l2(g,A,a, mu,nu,lambda);   
        
end
time(nt) = toc;
        [xIt, elx, ely, elz] = local_3Dmax_large(u1);

%% evaluation 
[re, pr] = Eval_v1(xIt, interest_reg); 
recall(nt) =  re;
precision(nt) = pr; 

fprintf('Recall = %3.2f%%\n',recall(nt)*100);
fprintf('Precision = %3.2f%%\n',precision(nt)*100);
fprintf('Cost time = %3.2f seconds\n',time(nt));
fprintf('---\n');
end






