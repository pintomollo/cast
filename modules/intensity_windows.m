function all_values = intensity_windows(all_spots)
% WINDOW_INTENSITIES

  % For convenience, work always with cells
  if (~iscell(all_spots))
    all_spots = {all_spots};
  end

  % Assign the output
  all_values = cell(size(all_spots));

  % Loop over all the planes
  for nimg = 1:length(all_spots)

    % Get the current set of spots
    spots = all_spots{nimg};

    % Compute the corresponding values
    values = [spots(:,1:7) spots(:,5).*prod(spots(:,3:4), 2)];

    % Store them
    all_values{nimg} = values;
  end

  % If we have only one element, use the matrix directly
  if (numel(all_values)==1)
    all_values = all_values{1};
  end

  return;
end
