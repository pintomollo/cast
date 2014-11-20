% NL_MEANS_MEX C implementation to perform non-local means denoising as described in
% [1]. Note that this code is designed to be used through the nl_means function
% (libraries/nl_means.m).
%
%   [M1,Wx,Wy] = NL_MEANS_MEX(M,HA,HA,VX,VY,T,MAX_DIST,DO_MEDIAN,DO_PATCHWISE, ...
%   MASK_PROCESS,MASK_COPY,EXCLUDE_SELF) filters M into M1 using Non-local Means. All
%   additional are identical to the original code from Gabriel Peyre.
%
% References:
% [1] Buades A, Coll B, Morel JM, "On image denoising methods". SIAM Multiscale Model
%     Simul 4 (2005) 490-530.
%
% This code is a simplified version of the toolbox from Gabriel Peyre (2006):
% http://www.mathworks.com/matlabcentral/fileexchange/13619-toolbox-non-local-means
% All Copyrights to him
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 19.06.2014
