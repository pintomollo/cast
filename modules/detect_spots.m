function spots = detect_spots(imgs, thresh, max_size, intens_thresh)
% DETECT_SPOTS detects spots in biological images using the "A-trous" method [1].
%
%   SPOTS = DETECT_SPOTS(IMG) returns a list of detected spots in IMG using IMATROU
%   and a noise threshold of 3 (see imatrou.m). SPOTS is a Nx3 matrix where each row
%   has the structure [x y], where x,y are the pixel position of the spot in carthesian
%   coordinates.
%
%   SPOTS = DETECT_SPOTS(IMG, THRESH) utilises a hard threshold THRESH to filter out
%   noisy detections in the wavelet transform (k, from t_i in [1], see imatrou.m)
%
%   SPOTS = DETECT_SPOTS(..., THRESH, MAX_SIZE) provides in addition an upper
%   bound to the detected spot size (see imatrou.m) to spare computations.
%
%   SPOTS = DETECT_SPOTS(IMGS, ...) returns a cell-vector containing the detections 
%   for each plane contained in IMGS.
%
% References:
%   [1] Olivo-Marin, J.-C. Extraction of spots in biological images using 
%       multiscale products. Pattern Recognit. 35, 1989-1996 (2002).
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 23.06.2014

  % Input checking
  if (nargin == 0)
    error('CAST:detect_spots', 'Not enough parameters provided (min=1)');
  elseif (nargin < 2)
    thresh = 3;
    max_size = Inf;
    intens_thresh = 0;
  elseif (nargin < 3)
    max_size = Inf;
    intens_thresh = 0;
  elseif (nargin < 4)
    intens_thresh = 0;
  end

  % Image size
  [m,n,nframes] = size(imgs);

  % Get an upper bound for the size
  max_size = ceil(min(max_size, max(m,n)));

  % Initialize the output variable
  spots = cell(nframes, 1);

  % Convert just in case
  imgs = double(imgs);

  % Create a mask to identify the local maxima
  tmp_size = ceil(max_size/2);
  tmp_size = tmp_size + mod(tmp_size+1, 2);
  mask = ones(tmp_size);
  mask((end-1)/2+1) = 0;

  % If need be, perpare the averaging mask
  if (intens_thresh > 0)
    mask_avg = ones(tmp_size);
    mask_avg = mask_avg / numel(mask_avg);
  else
    avgs = 1;
  end

  % We iterate over the frames
  for i = 1:nframes

    % Get the current plane
    img = imgs(:, :, i);

    % Performs the actual spot detection "a trous" algorithm [1]
    atrous = imatrou(img, max_size, thresh);

    % Compute the local average
    if (intens_thresh > 0)
      avgs = imfilter(img, mask_avg);
    end

    % Get the local maxima
    bw = (atrous > 0) & (img >= imdilate(img, mask)) & (avgs >= intens_thresh);

    % Shrink them to single pixel values
    bw = bwmorph(bw, 'shrink', Inf);

    % And get the list of candidates
    [coord_y, coord_x] = find(bw);

    % Invert to carthesian coordinates
    estim_pos = [coord_x, coord_y];

    % And store the results
    spots{i} = estim_pos;
  end

  % In case we have only one frame, keep only the list
  if (numel(spots)==1)
    spots = spots{1};
  end

  return;
end
