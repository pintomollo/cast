function img = draw_window(params, size_img)
% DRAW_WINDOW represents an estimation window into an image.
%
%   IMG = DRAW_WINDOW(PARAMS, SIZE_IMG) creates an IMG of SIZE_IMG containing a
%   representation of the estimated window characterized by PARAMS. A window is
%   thus depicted by a rectangular area with values corresponding to its mean pixel
%   value. PARAMS should be consistent with those defined in estimate_window.m
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 31.03.2015

  % Prepare the ouptut image
  img = zeros(size_img);

  % Get the corresponding indexes
  xindx = round(params(1) + [-params(3):params(3)]);
  yindx = round(params(2) + [-params(4):params(4)]);

  % Keep only the valid ones
  xindx = xindx(xindx > 0 & xindx <= size_img(2));
  yindx = yindx(yindx > 0 & yindx <= size_img(1));

  % Assign the mean value to the visible rectangular area
  img(yindx, xindx) = params(5);

  return;
end
