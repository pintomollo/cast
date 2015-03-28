function params = estimate_window(imgs, estim_pos, wsize)

  % Input checking and default values
  if (nargin < 3)
    error('CAST:estimate_spots', 'Not enough parameters provided (min=3)');
  end

  % Get the image size
  [m,n,p] = size(imgs);

  % For convenience, work only with cells
  if (~iscell(estim_pos))
    estim_pos = {estim_pos};
  end

  % Initialize the output
  params = cell(p, 1);

  % Create a mask to identify the local maxima
  mask = ones(2*wsize + 1);
  mask((end-1)/2+1) = 0;
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

    % Store the averages
    params{nimg} = [curr_pos(:,1:2) repmat(wsize, length(estim_pos), 1), ...
                    local_mean(estim_pos) local_stds(estim_pos) curr_pos(:,3:end)];
  end

  % If we have only one plane, return the matrix alone
  if (numel(params)==1)
    params = params{1};
  end

  return;
end
