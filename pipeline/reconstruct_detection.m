function detected = reconstruct_detection(imgs, spots, draw)
% RECONSTRUCT_DETECTION creates an image of the detected gaussian spots.
%
%   RIMG = RECONSTRUCT_DETECTION(IMG, SPOTS) creates a reconstructed image RIMG from
%   the detection of gaussian SPOTS. SPOTS should be organised with one detection per
%   row as follows: [X_coord, Y_coord, sigma, amplitude, ...]. No background is added.
%   IMG is required to infer properly the size of RIMG.
%
%   RIMGS = RECONSTRUCT_DETECTION(IMGS, SPOTS_GROUPS) reconstructs all RIMGS using the
%   detected SPOTS_GROUPS, organized in a cell array for the same size as the number of
%   planes in IMGS.
%
%   To work properly, this function requires library/GaussMask2D.m
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 07.07.2014

  % Get the size of the image
  [m,n,p] = size(imgs);

  % Initialize the output
  detected = zeros(size(imgs));
  size_img = [m,n];

  % For convenience, always work with cell arrays
  if (~iscell(spots))
    spots = {spots};
  end

  % Something went wrong...
  if (length(spots) ~= p)
    warning('CAST:reconstruct_detection', 'Sizes does not correspond between the image and the detections.');

    return;
  end

  % The temporary plane
  zero = zeros(size_img);

  % Loop over each plane
  for i = 1:p

    % An empty temporary plane
    img = zero;

    % The current detections
    curr_spots = spots{i};

    % Keep only the valid ones
    curr_spots = curr_spots(~any(isnan(curr_spots), 2), :);

    % Loop over each spot
    for s = 1:size(curr_spots, 1)

      % Get its parameters
      gauss_params = curr_spots(s,:);

      % Add its gaussian shape to the current plane
      img = img + draw(gauss_params, size_img);
    end

    % Store the reconstructed image
    detected(:,:,i) = img;
  end

  % Cast it back to the original data type
  detected = cast(detected, class(imgs));

  return;
end