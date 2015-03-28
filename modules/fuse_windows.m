function fused_spots = fuse_windows(spots, values, overlap_thresh)

  % Prepare the output
  fused_spots = NaN(0, size(spots, 2));

  % We first need to determine the all-to-all distance
  distx = abs(bsxfun(@minus, spots(:,1), spots(:,1).'));
  disty = abs(bsxfun(@minus, spots(:,2), spots(:,2).'));

  % And their respective sizes
  radx = bsxfun(@plus, values(:,3), values(:,3).');
  rady = bsxfun(@plus, values(:,4), values(:,4).');

  % Now check which ones should be fused
  fused = (distx < (1-overlap_thresh) * radx) & (disty < (1-overlap_thresh) * rady) ;

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
        fused_spots = [fused_spots; spots(groups, :)];

      % Otherwise, need to create a new spot
      else

        % Get the spots to be fused
        curr_spots = spots(groups, :);
        curr_values = values(groups, :);

        % Utilize the estimated signal for weighting the average
        intensities = curr_values(:,8);
        intensities = intensities / sum(intensities);

        % Compute the future position
        target = bsxfun(@times, curr_values(:,1:2), intensities);
        target = sum(target, 1)/length(intensities);

        % And their relative distance to the new position
        center_dist = sqrt(sum(bsxfun(@minus, curr_values(:,1:2), target).^2, 2));

        % Gaussian-like distance kernel for weighting the average, weighted by the
        % signal intensity once more
        weights = exp(-center_dist ./ (2*mean(curr_values(:, 3:4),2).^2));
        weights = weights .* curr_values(:,8);
        weights = weights / sum(weights);

        % Average and store the new spot
        fused_spots = [fused_spots; sum(bsxfun(@times, curr_spots, weights), 1)];
      end

      % Remove the fused spots from the list
      fused(:, groups) = false;
    end
  end

  return;
end
