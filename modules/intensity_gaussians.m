function all_values = intensity_gaussians(all_spots)
% INTENSITY_GAUSSIANS computes the total intensity of a 2D Gaussian spot.
%
%   INTENSITIES = INTENSITY_GAUSSIANS(PARAMS) returns the value of the total signal
%   INTENSITIES of 2D Gaussian spots defined by their PARAMS. The total signal is
%   defined as the 2D integral of a Gaussian shape.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 31.03.2015

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
    values = 2*pi.*spots(:,4).*spots(:,3).^2;

    % Store them
    all_values{nimg} = values;
  end

  % If we have only one element, use the matrix directly
  if (numel(all_values)==1)
    all_values = all_values{1};
  end

  return;
end
