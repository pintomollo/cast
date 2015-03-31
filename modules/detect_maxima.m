function maxs = detect_maxima(imgs, window_size)
% DETECT_MAXIMA detects local maxima in images.
%
%   MAXS = DETECT_MAXIMA(IMG) returns a list of local maxima in IMG using a window of
%   size 11x11.
%
%   MAXS = DETECT_MAXIMA(IMG, N) utilises a window of size 2*N+1.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 22.03.2015

  % Input checking
  if (nargin == 0)
    error('CAST:detect_maxima', 'Not enough parameters provided (min=1)');
  elseif (nargin < 2)
    window_size = 5;
  end

  % Image size
  [m,n,nframes] = size(imgs);

  % Initialize the output variable
  maxs = cell(nframes, 1);

  % Convert just in case
  imgs = double(imgs);

  % Create a mask to identify the local maxima
  mask = ones(2*window_size + 1);
  mask((end-1)/2+1) = 0;

  % We iterate over the frames
  for i = 1:nframes

    % Get the current plane
    img = imgs(:, :, i);

    % Get the local maxima
    bw = (img >= imdilate(img, mask));

    % Shrink them to single pixel values
    bw = bwmorph(bw, 'shrink', Inf);

    % And get the list of candidates
    [coord_y, coord_x] = find(bw);

    % Invert to carthesian coordinates
    estim_pos = [coord_x, coord_y];

    % And store the results
    maxs{i} = estim_pos;
  end

  % In case we have only one frame, keep only the list
  if (numel(maxs)==1)
    maxs = maxs{1};
  end

  return;
end
