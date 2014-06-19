function [M1] = nl_means(M, T, k, max_dist, do_median, ndims)
% NL_MEANS denoises an image using non-local Means [1].
%
%   [M] = NL_MEANS(M) denoises M using the default values of the NL_MEANS algorithm.
%
%   [M] = NL_MEANS(M, T, K, D, O, N) defines the variance of the gaussian noise T, the
%   half size of the neighborhood K used to compute the windows size and the maximum
%   distance to restrict the search D. O defines if a L1 robust NL-Means (true) or
%   the traditional algorithm (false) is performed and N is the maximum number of PCA
%   dimensions to be used. Default values are K=3, T=0.05, D=15, O=false, N=25.
%   Note that K cannot exceed 9.
%
% References:
% [1] Buades A, Coll B, Morel JM, "On image denoising methods". SIAM Multiscale Model
%     Simul 4 (2005) 490–530.
%
% This code is a simplified version of the toolbox from Gabirel Peyre (2006).
% All Copyrights to him
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 19.06.2014

switch nargin
  case 1
    T=0.05;
    k=3;
    max_dist=15;
    do_median=false;
    ndims=25;
  case 2
    k=3;
    max_dist=15;
    do_median=false;
    ndims=25;
  case 3
    max_dist=15;
    do_median=false;
    ndims=25;
  case 4
    do_median=false;
    ndims=25;
  case 5
    ndims=25;
  case 0
    disp('Error: no image provided !')
    M1 = NaN;
end

if (k>9)
  disp('Error: neighborhood cannot be larger than 9 !')
  M1 = NaN(size(M));

  return;
end

[m,n,s] = size(M);
[Vy,Vx] = meshgrid(1:n,1:m);

M1=M;

for i=1:s
  % lift to high dimensional patch space
  [Ha,P,Psi] = perform_lowdim_embedding(M(:,:,i),k,ndims,Vy,Vx);

  [M1(:,:,i),Wx,Wy] = nl_means_mex(M(:,:,i),Ha,Ha,Vx-1,Vy-1,T,max_dist, do_median, false, [], [], 0);
end

return;
end

function [H,P,Psi] = perform_lowdim_embedding(M,k,ndims, Vy, Vx)

% perform_lowdim_embedding - perform a patch wise dimension extension
%
%   [H,options.P, options.Psi] = perform_lowdim_embedding(M,options);
%
%   M = perform_lowdim_embedding(H,options);
%
%   This function lift each pixel of an image (can be a color image)
%   to a vector that incorporate neighboorhood relationship.
%
%   Each pixel is replaced by the vector containing the values of the
%   neighbooring pixels and then dimension reduction is applyed to 
%   avoid manipulating very high dimensional vectors.
%
%   options.ndims gives the dimensionality for PCA.
%
%   Copyright (c) 2006 Gabriel Peyr?

mask = 'cst';
phi = ones(2*k+1);

[m,n,s] = size(M);

% perform patch wise embedding
s = size(M,3);
% extract patches
sampling = 'uniform';
H = compute_patch_library(M,k,sampling, Vy, Vx);
H = H .* repmat( phi, [1 1 s n*m] );
% turn into collection of vectors
H = reshape(H, [s*(2*k+1)^2 n*m]);

ndims = min(ndims,size(H,1));

% compute PCA projection
nbexemplars = min(n*m,5000);
sel = randperm(n*m);
sel = sel(1:nbexemplars);

%[P,X1,v,Psi] = mypca(H(:,sel),ndims);
P = pca(H(:,sel).', 'Algorithm', 'eig');

P = P(:,1:ndims);
Psi = [];

ndims = size(P,2);
% perform actual PCA projection
%H = H - repmat( Psi, [1 n*m] );
H = P'*H;
% reshape matrix
H = reshape(H, [ndims m n]);
H = shiftdim(H,1);
return;
end

function [H] = compute_patch_library(M,w,sampling, Vy, Vx)

% [H,X,Y] = compute_patch_library(M,w,options);
%
%   M is the texture
%   w is the half-width of the patch, so that each patch
%       has size (2*w+1,2*w+1,s) where s is the number of colors.
%
%   H(:,:,:,i) is the ith patch (can be a color patch).
%   X(i) is the x location of H(:,:,:,i) in the image M.
%   Y(i) is the y location of H(:,:,:,i) in the image M.
%
%   options.sampling can be set to 'random' or 'uniform'
%   If options.sampling=='random' then you can define
%       options.nbr as the number of random patches and/or
%       option.locations_x and option.locations_y.
%
%   If w is a vector of integer size, then the algorithm 
%   compute a set of library, one for each size, 
%   and use the same location X,Y for each patch.
%   H{k} is the k-th library.
%
%   You can define options.wmax to avoid too big patch.
%   In this case, if w>wmax, the texture M will be filtered, and the patches
%   will be subsampled to match the size.
%
%   Copyright (c) 2006 Gabriel Peyr?

[m,n,s] = size(M);

% do some padding to avoid boundary problems
M = padarray(M,w([1 1]),'symmetric');

ww = 2*w+1;
p = n*m;

Y=Vy+w;
X=Vx+w;
%[Y,X] = meshgrid(w+1:w+n, w+1:w+m);

X = X(:);
Y = Y(:);

H = zeros(ww,ww,s,p);
B = H(:,:,:,1);

%%% in this case, a fast sampling can be used %%%
[dY,dX] = meshgrid(-w:w,-w:w);
Xp = repmat( reshape(X,[1,1,1,p]) ,[ww ww s 1]) + repmat(dX,[1 1 s p]);
Yp = repmat( reshape(Y,[1,1,1,p]) ,[ww ww s 1]) + repmat(dY,[1 1 s p]);
Cp = repmat( reshape(1:s,[1 1 s]), [ww ww 1 p]);
I = sub2ind(size(M), Xp,Yp,Cp);
H = M(I);
return;
end
