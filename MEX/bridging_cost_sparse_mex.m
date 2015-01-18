% BRIDGING_COST_SPARSE_MEX computes the cost matrix, in sparse form, for gaussian
% spots.
%
%   COSTS = JOINING_COST_SPARSE_MEX(SPOTS1, SPOTS2, MAX_DIST, MAX_GAP, MAX_RATIO)
%   computes the COSTS matrix for bridging SPOTS1 with SPOTS2 as defined in [1], with
%   a new time component cost = d^2 + (t/MAX_GAP)^2 to favor consecutive events,
%   MAX_DIST, MAX_GAP and MAX_RATIO define spatial, temporal and intensity thresholds
%   used to filter out potential assignments. To take advantage of sparse matrices,
%   the transform -exp(-cost) is used.
%
% References:
%   [1] Jaqaman K, Loerke D, Mettlen M, Kuwata H, Grinstein S, et al. Robust
%       single-particle tracking in live-cell time-lapse sequences. Nat Methods 5:
%       695-702 (2008).
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 06.07.2014
