function [fused_spots, all_goods] = filter_spots(all_spots, all_intensities, ...
                                    fusion, extrema, overlap_thresh)
% FILTER_SPOTS filters a list of estimated spots based on their properties
% and fuses overlapping ones, assuming some sort of oversampling.
%
%   SPOTS = FILTER_SPOTS(SPOTS, INTENSITIES, FUSE_FUNC) removes from SPOTS the estimates
%   which have negative or imaginary parameter values. In addition, utilizes FUSE_FUNC
%   to fuse spots having more than 75% overlap.
%
%   SPOTS = FILTER_SPOTS(..., EXTREMA) specifies tighter EXTREMA values to be applied
%   during the filtering. EXTREMA should be a 2-rows matrix with lower bounds on the first,
%   and upper bound on the second row.
%
%   SPOTS = FILTER_SPOTS(..., OVERLAP) defines the threshold percentage of OVERLAP
%   required for fusion between spots.
%
%   [SPOTS, KEPT] = FILTER_SPOTS(...) returns in addition an array of the same size as
%   the input SPOTS containing defining whether the corresponding spot was KEPT.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 26.06.2014

  % Input checking and default values
  if (nargin < 3)
    error('CAST:filter_spots', 'Not enough parameters provided (min=3)');
  elseif (nargin < 4)
    extrema = NaN(2,0);
    overlap_thresh = 0.75;
  elseif (nargin < 5)
    if (numel(extrema) == 1)
      overlap_thresh = extrema;
      extrema = NaN(2,0);
    else
      overlap_thresh = 0.75;
    end
  end

  % Accept only double-valued extrema
  if (size(extrema, 1) ~= 2)
    extrema = NaN(2,0);
  end

  % For convenience, work always with cells
  if (~iscell(all_spots))
    all_spots = {all_spots};
    all_intensities = {all_intensities};
  end

  % Assign the output
  fused_spots = cell(size(all_spots));
  all_goods = cell(size(all_spots));

  % The number of properties belonging to a spot
  nprops = -1;

  % Loop over all the planes
  for nimg = 1:length(all_spots)

    % Get the current set of spots
    spots = all_spots{nimg};
    intensities = all_intensities{nimg};

    % No work needed
    if (isempty(spots))
      continue;
    end

    % Measure the actual number of properties
    if (nprops < 0)
      nprops = size(spots, 2);

      % Adapt the extrema
      extrema = [extrema, repmat([0; Inf], 1, (nprops-2) - size(extrema, 2))];
    end

    % Apply the extrema thresholds, ignoring the XY coordinates
    goods = bsxfun(@ge, spots(:, 3:end), extrema(1,:)) & ...
            bsxfun(@le, spots(:, 3:end), extrema(2,:)) & ...
            isfinite(spots(:, 3:end)) & isreal(spots);
    goods = all(goods, 2);

    % Keep only the good spots
    spots = spots(goods,:);
    intensities = intensities(goods,:);

    % Now fuse the spots
    curr_fused = fusion(spots, intensities, overlap_thresh);

    % Store the whole list
    fused_spots{nimg} = curr_fused;
    all_goods{nimg} = goods;
  end

  % If we have only one element, use the matrix directly
  if (numel(fused_spots)==1)
    fused_spots = fused_spots{1};
    all_goods = all_goods{1};
  end

  return;
end
