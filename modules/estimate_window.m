function params = estimate_window(imgs, estim_pos, wsize)
% ESTIMATE_WINDOW performs an estimation of the mean and standard deviation of the
% pixel values inside a window of a give size.
%
%   PARAMS = ESTIMATE_WINDOW(IMG, POS, WSIZE) estimates a window of size 2*WSIZE+1
%   around POS, utilizing the pixels from IMG to estimate the various statistics.
%   PARAMS is a Nx(5+) matrix with rows corresponding to the following parameters:
%     [center_x, center_y, width, (height), mean, standard_deviation, ...] where
%     height can be ignored if the window is square, and where "..." refers to
%     additional data from POS.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 31.03.2015

  % Input checking and default values
  if (nargin < 3)
    error('CAST:estimate_window', 'Not enough parameters provided (min=3)');
  end

  % Get the image size
  [m,n,p] = size(imgs);

  % For convenience, work only with cells
  if (~iscell(estim_pos))
    estim_pos = {estim_pos};
  end

  % Initialize the output
  params = cell(p, 1);

  % Create a mask to compute the local statistics
  mask = ones(2*wsize + 1);
  navg = 1/numel(mask);

  % Now loop over each plane of the stack
  for nimg = 1:p

    % Extract the current image and positions
    img = imgs(:,:,nimg);
    curr_pos = estim_pos{nimg};

    % Get the corresponding indexes
    estim_pos = sub2ind([m,n], curr_pos(:,2), curr_pos(:,1));

    % Get the local statistics
    local_mean = imfilter(img, mask*navg);
    local_stds = stdfilt(img, mask);

    % Store the properties of the windows
    params{nimg} = [curr_pos(:,1:2) repmat(wsize, length(estim_pos), 1), ...
                    local_mean(estim_pos) local_stds(estim_pos) curr_pos(:,3:end)];
  end

  % If we have only one plane, return the matrix alone
  if (numel(params)==1)
    params = params{1};
  end

  return;
end
