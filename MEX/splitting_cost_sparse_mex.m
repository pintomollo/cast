% SPLITTING_COST_SPARSE_MEX computes the cost matrix, and the alternative cost
% vector, in sparse form, for spots.
%
%   [COSTS, ALT_COSTS] = SPLITTING_COST_SPARSE_MEX(SPOTS1, SPOTS2, MAX_DIST, MAX_GAP, ...
%   MAX_RATIO, AVG_DIST, SPOTS, LINKS) computes the COSTS matrix for splitting SPOTS1
%   to SPOTS2 as defined in [1], as well as the vector ALT_COSTS for not splitting
%   the corresponding tracks [1]. MAX_DIST, MAX_GAP and MAX_RATIO define spatial,
%   temporal and intensity thresholds used to filter out potential assignments.
%
%   CAN_SPLIT = SPLITTING_COST_SPARSE_MEX(SPOTS1, SPOTS2, MAX_DIST, MAX_GAP) returns
%   a boolean vector defining whether SPOTS2 CAN_SPLIT from SPOTS1.
%
% References:
%   [1] Jaqaman K, Loerke D, Mettlen M, Kuwata H, Grinstein S, et al. Robust
%       single-particle tracking in live-cell time-lapse sequences. Nat Methods 5:
%       695-702 (2008).
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 06.07.2014
