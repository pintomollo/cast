function all_values = window_intensities(all_spots, window_size)
% WINDOW_INTENSITIES

  % For convenience, work always with cells
  if (~iscell(all_spots))
    all_spots = {all_spots};
  end

  % Assign the output
  all_values = cell(size(all_spots));

  % Precompute some size values
  avg_radius = mean(window_size);
  area = prod(window_size);

  % Loop over all the planes
  for nimg = 1:length(all_spots)

    % Get the current set of spots
    spots = all_spots{nimg};

    % Compute the corresponding values
    values = [spots(:,1:2) avg_radius*ones(size(spots, 1),1) spots(:,3) spots(:,3)*area];

    % Store them
    all_values{nimg} = values;
  end

  return;
end
