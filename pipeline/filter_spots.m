function fused_spots = filter_spots(all_spots, all_values, extrema_size, min_intensity, ...
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
  if (nargin == 0)
    error('CAST:filter_spots', 'Not enough parameters provided (min=1)');
  elseif (nargin < 3)
    extrema_size = [0 Inf];
    min_intensity = 0;
    overlap_thresh = 0.75;
  elseif (nargin < 4)
    min_intensity = 0;
    overlap_thresh = 0.75;
  elseif (nargin < 5)
    overlap_thresh = 0.75;
  end

  % Maybe one want to ignore the size filtering
  if (isempty(extrema_size))
    extrema_size = [0 Inf];
  end

  % For convenience, work always with cells
  if (~iscell(all_spots))
    all_spots = {all_spots};
  end

  % Assign the output
  fused_spots = cell(size(all_spots));

  % Loop over all the planes
  for nimg = 1:length(all_spots)

    % Get the current set of spots
    spots = all_spots{nimg};
    values = all_values{nimg};

    % Prepare the list
    curr_fused = NaN(0,size(spots,2));

    % No work needed
    if (isempty(spots))
      continue;
    end

    % Spots should be organised with intensity in column 4 and radii in column 3
    goods = (values(:,4) > min_intensity & values(:,3)*3 > extrema_size(1) ...
           & ~any(imag(values), 2) & values(:,3) < extrema_size(2));

    % Keep only the good spots
    spots = spots(goods,:);
    values = values(goods,:);

    % Now, for the fusion part, we first need to determine the all-to-all distance
    dist = sqrt(bsxfun(@minus, spots(:,1), spots(:,1).').^2 + bsxfun(@minus, spots(:,2), spots(:,2).').^2);

    % And their respective sizes
    rads = values(:,3);
    rads = bsxfun(@plus, rads, rads.');

    % Now check which ones should be fused
    fused = (dist < (1-overlap_thresh) * rads);

    % Loop over all spots to see if fusion is required. Note that each spots should
    % at least fuse with itself !
    for i = 1:size(spots, 1)

      % Get the list of fusion required with the current spot
      groups = fused(:,i);
      prev_groups = false(size(groups));

      % Now loop to include all spots which need to be fused together in a chain-like
      % structure. In the worst case, we need to loop over all spots once.
      for j = 1:size(spots, 1)

        % Check for convergeance
        if (~any(xor(groups, prev_groups)))
          break;
        else
          prev_groups = groups;
          groups = any(fused(:, groups), 2);
        end
      end

      % No group could exist if the current spots as already been fused
      if (any(groups))

        % Fused with itself !
        if (sum(groups) == 1)
          curr_fused = [curr_fused; spots(groups, :)];

        % Otherwise, need to create a new spot
        else

          % Get the spots to be fused
          curr_spots = spots(groups, :);
          curr_values = values(groups, :);

          % Utilize the estimated signal for weighting the average
          intensities = curr_values(:,5);
          intensities = intensities / sum(intensities);

          % Compute the future position
          target = bsxfun(@times, curr_values(:,1:2), intensities);
          target = sum(target, 1)/length(intensities);

          % And their relative distance to the new position
          center_dist = sqrt(sum(bsxfun(@minus, curr_values(:,1:2), target).^2, 2));

          % Gaussian-like distance kernel for weighting the average, weighted by the
          % signal intensity once more
          weights = exp(-center_dist ./ (2*curr_values(:, 3).^2));
          weights = weights .* curr_values(:,5);
          weights = weights / sum(weights);

          % Average and store the new spot
          curr_fused = [curr_fused; sum(bsxfun(@times, curr_spots, weights), 1)];
        end

        % Remove the fused spots from the list
        fused(:, groups) = false;
      end
    end

    % Store the whole list
    fused_spots{nimg} = curr_fused;
  end

  % If we have only one element, use the matrix directly
  if (numel(fused_spots)==1)
    fused_spots = fused_spots{1};
  end

  return;
end
