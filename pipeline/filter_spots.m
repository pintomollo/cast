function fused_spots = filter_spots(all_spots, all_intensities, fusion, extrema, ...
                                    overlap_thresh)
% FILTER_SPOTS filters a list of estimated spots based on their intensity and size,
% and fuses overlapping ones, assuming some sort of oversampling.
%
%   SPOTS = FILTER_SPOTS(SPOTS) removes from SPOTS the estimates which have negative
%   intensities or imaginary parameter values. In addition, fuse spots having more
%   than 75% overlap (measured as the distance/radius ratio). SPOTS should be a cell
%   vector of estimated spots as described in estimate_spots.m.
%
%   SPOTS = FILTER_SPOTS(SPOTS, SIZE_BOUNDS) filters in addition on the size of the
%   detected spots. SIZE_BOUNDS should contain both a lower and an upper bound.
%
%   SPOTS = FILTER_SPOTS(SPOTS, SIZE_BOUNDS, MIN_INTENS) removes in addition spots
%   with an amplitude smaller than MIN_INTENS. Put SIZE_BOUNDS to an empty array to
%   ignore this parameter.
%
%   SPOTS = FILTER_SPOTS(SPOTS, SIZE_BOUNDS, MIN_INTENS, OVERLAP) defines the
%   threshold percentage of OVERLAP required for fusion between spots. Note that the
%   resulting spot will be a weighted average of the fused spots, based on their
%   respective signal intensity (i.e. intensity * radii^2).
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
  end

  % If we have only one element, use the matrix directly
  if (numel(fused_spots)==1)
    fused_spots = fused_spots{1};
  end

  return;
end
