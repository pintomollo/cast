function [gauss_params] = estimate_spots(imgs, estim_pos, wsize, thresh, niter, ...
                                         stop, weight, fit_full)
% ESTIMATE_SPOTS performs an estimation of the size and shape of gaussian spots using
% an iterative least-square fitting approach [1].
%
%   GAUSS = ESTIMATE_SPOTS(IMG, POS, WSIZE) fits 2D gaussians at POS where spots
%   where identified, utilizing the pixels from IMG in a window of WSIZE around POS.
%   Note that IMG should be background substracted for the fitting to operate. By
%   default, the iterative approach proposed in [1] is utilized for 15 iterations
%   with an additional weighting coefficient of 0.1. Note also that we extended the
%   fit to 2D symmetric gaussians instead of a 1D in [1].
%   GAUSS is a Nx(4+) matrix with rows corresponding to the following parameters:
%     [mu_x, mu_y, sigma, ampl, ...] where "..." refers to additional data from POS.
%
%   GAUSS = ESTIMATE_SPOTS(..., THRESH) utilizes only the pixels brighter than THRESH
%   to perform the regression (as proposed in [1]). A typical value should be the
%   backgound noise variance (see estimate_noise.m).
%
%   GAUSS = ESTIMATE_SPOTS(..., THRESH, NITER, STOP, WEIGTH) specifies the number of
%   iterations NITER, the stopping criterion STOP (the sum of absolute differences
%   between successive regression coefficients, [1]) and the additional weighting
%   coefficient WEIGHT (added to prevent oscillations in the fitting).
%
%   GAUSS =  ESTIMATE_SPOTS(..., FIT_FULL) when true also fits mu_x and mu_y using
%   the same framework. By default, the gaussian spots are forced to be centered on
%   POS to prevent instabilities when other spots are present in the vicinity.
%
%   GAUSS = ESTIMATE_NOISE(STACK, ...) estimates the spots in each plane separately,
%   returning a cell vector of GAUSS estimates. Note that POS should also be a cell
%   vector of coordinates corresponding to the planes of STACK.
%
% References:
%   [1] Guo, H, A Simple Algorithm for Fitting a Gaussian Function [DSP Tips and
%       Tricks]. IEEE Signal Process Mag 28: 134-137, (2011).
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 26.06.2014

  % Input checking and default values
  if (nargin < 3)
    error('Tracking:estimate_spots', 'Not enough parameters provided (min=3)');
  elseif (nargin < 4)
    thresh = 0;
    niter = 15;
    stop = 0;
    weight = 0.1;
    fit_full = false;
  elseif (nargin < 5)
    niter = 15;
    stop = 0;
    weight = 0.1;
    fit_full = false;
  elseif (nargin < 6)
    stop = 0;
    weight = 0.1;
    fit_full = false;
  elseif (nargin < 7)
    weight = 0.1;
    fit_full = false;
  elseif (nargin < 8)
    fit_full = false;
  end

  % Maybe fit_full was provided at some other place...
  if (islogical(thresh) || isempty(thresh))
    fit_full = thresh;
    thresh = 0;
  elseif (islogical(niter) || isempty(niter))
    fit_full = niter;
    niter = 15;
  end

  % An empty fit_full  has a special meaning !
  fit_intens = false;
  if (isempty(fit_full))
    fit_full = false;
    fit_intens = true;
  end

  % Perform at least one iteration
  niter = max(niter, 1);

  % Get the image size
  [m,n,p] = size(imgs);

  % For convenience, work only with cells
  if (~iscell(estim_pos))
    estim_pos = {estim_pos};
  end

  % Initialize the output
  gauss_params = cell(p, 1);

  % Now we try to pre-compute a maximum of vectors to speed up the regressions !

  % Create an index map to extract the sub-windows
  wsize = max(ceil(wsize), 1);
  indx = [-wsize:wsize];
  [X,Y] = meshgrid(indx.', indx);

  % Compute the relative position indexes for the regressions (cf. nested functions)
  X2 = X.^2;
  Y2 = Y.^2;
  Z  = X2 + Y2;
  Z2 = Z .* Z;
  XY = X .* Y;
  XZ = X .* Z;
  YZ = Y .* Z;

  % Now loop over each plane of the stack
  for nimg = 1:p

    % Extract the current image and positions
    img = imgs(:,:,nimg);
    curr_pos = estim_pos{nimg};

    % Get the number of candidate positions
    nspots = size(curr_pos, 1);

    % Initialize the parameter matrix
    curr_params = NaN(nspots, 4);

    % Now loop over all spots
    for i=1:nspots
      pos = curr_pos(i,:);

      % Interpolate the sub-window
      window = bilinear_mex(img, X+pos(1), Y+pos(2), false);

      % We keep only the brightest pixels as suggested in [1].
      goods = (window(:) > thresh);

      % Avoid empty windows
      if (any(goods))
        % Fit either a centered or a full symmetric 2d gaussian (or just the amplitude)
        if (fit_full)
          curr_params(i,:) = regress_2d_gaussian(window(goods), niter, ...
                                                            weight, stop);
        elseif (~fit_intens)
          curr_params(i,:) = regress_2d_centered_gaussian(window(goods), ...
                                                            niter, weight, stop);
        else
          curr_params(i,:) = regress_2d_amplitudes(window(goods), pos(3:end));
        end
      end
    end

    % We obviously cannot estimate data outside of our current window
    outside = any(abs(curr_params(:,1:2) / wsize) > 1, 2);
    curr_params(outside, :) = NaN;

    % Correct the position
    curr_params(:,1:2) = curr_params(:,1:2) + curr_pos(:,1:2);

    % Store the additional parameters to the output
    gauss_params{nimg} = [curr_params curr_pos(:,3:end)];
  end

  % If we have only one plane, return the matrix alone
  if (numel(gauss_params)==1)
    gauss_params = gauss_params{1};
  end

  return;

  function params = regress_2d_gaussian(s, niter, weight, stop)
  % Performing a least-square regression of a 2d symmetric gaussian, including the
  % center parameters, to the pixels s. We utilize nested functions to avoid having
  % to recompute the position matrices X to YZ.
  %
  % The regression has been derived from the equation of a 2D gaussian as in [1]:
  %    s = A * exp^(-((x - mu_x)^2+(y - mu_y)^2)/(2 * sigma^2))
  % => ln(s) = a + b*x + c*y + d*z; where z = x^2 + y^2
  %                                       a = ln(A) - (mu_x^2 + mu_y^2) / (2*sigma^2)
  %                                       b = mu_x / (sigma^2)
  %                                       c = mu_y / (sigma^2)
  %                                       d = -1 / (2 * sigma^2)
  %
  % when the solve the following system of equations: J * [a;b;c;d] = V
  %
  % where J(L-S) = [ 1   x    y    z  ;   and  V = [ln(s);
  %                  x   x^2  x*y  x*z;             x*ln(s);
  %                  y   x*y  y^2  y*z;             y*ln(s);
  %                  z   x*z  y*z  z^2]             z*ln(s)]
  %
  % all these terms being in addition summed on all positions/pixels and weighted
  % as proposed in [1] by s^2_(k-1).

    % Keep only the good pixels (goods is defined in the main function)
    x = X(goods);
    y = Y(goods);
    z = Z(goods);
    x2 = X2(goods);
    y2 = Y2(goods);
    z2 = Z2(goods);
    xy = XY(goods);
    xz = XZ(goods);
    yz = YZ(goods);

    % Precompute the log of the signal
    ls = log(s);

    % Set up the coefficients
    prev_coeffs = [];

    % Iterate the regression
    for n = 1:niter

      % Decide if prev_coeffs exists
      has_prev = (n>1);

      % If no previous estimate exists, utilise the signal
      if (~has_prev)
        se = s;

      % Otherwise, utilize the gaussian itself
      else
        se = exp(prev_coeffs(1) + prev_coeffs(2)*x + prev_coeffs(3)*y + ...
                 prev_coeffs(3)*z);
      end

      % Precompute the signal part
      se2 = se.^2;
      se2ls = se2 .* ls;

      % And the Jacobian terms
      ss2 = sum(se2);
      sxs2 = sum(x.*se2);
      sx2s2 = sum(x2.*se2);
      sys2 = sum(y.*se2);
      sy2s2 = sum(y2.*se2);
      szs2 = sum(z.*se2);
      sxys2 = sum(xy.*se2);
      sxzs2 = sum(xz.*se2);
      syzs2 = sum(yz.*se2);
      sz2s2 = sum(z2.*se2);

      % Build the Jacobian matrix
      mat = [ss2   sxs2  sys2  szs2; ...
             sxs2  sx2s2 sxys2 sxzs2; ...
             sys2  sxys2 sy2s2 syzs2; ...
             szs2  sxzs2 syzs2 sz2s2];

      % And the results vector
      res = [sum(se2ls); sum(x.*se2ls); sum(y.*se2ls); sum(z.*se2ls)];

      % Avoid badly scaled matrix
      rs = rcond(mat);
      if (abs(det(mat)) < 1e-5 || isnan(rs) || abs(rs) < 1e-3)
        coeffs = [-Inf -1 -1 Inf];
        break;
      end

      % Do the actual regression
      coeffs = mat \ res;

      % If we have already an estimate, check what's going on
      if (has_prev)

        % Have we converged yet ?
        if (sum(abs(coeffs-prev_coeffs))<stop)
          break;

        % Otherwise, compute a weighted average of the current coefficients
        else
          coeffs = coeffs*(1-weight) + prev_coeffs*weight;
        end
      else
        % Force them to be close to the center
        coeffs(2:3) = coeffs(2:3)*(1-weight);
      end

      % Store the coefficients for the next iteration
      prev_coeffs = coeffs;
    end

    % Extract the gaussian parameters
    mux = -coeffs(2)/(2*coeffs(4));
    muy = -coeffs(3)/(2*coeffs(4));
    sigma = sqrt(-1/(2*coeffs(4)));
    ampl = exp(coeffs(1) - (coeffs(2)^2 + coeffs(3)^2)/(4*coeffs(4)));

    % Store them and exit
    params = [mux muy sigma ampl];

    return;
  end

  function params = regress_2d_centered_gaussian(s, niter, weight, stop)
  % Similar to regress_2d_gaussian but having mu_x and mu_y both equal to 0, which
  % simplifies quite drastically the system of equations to be solved to:
  %
  %       J(L-S) = [ 1   z  ;   and  V = [ln(s);
  %                  z   z^2]             z*ln(s)]

    % Get the good positions
    z = Z(goods);
    z2 = Z2(goods);

    % Precompute
    ls = log(s);
    prev_coeffs = [];

    % Iterate
    for n = 1:niter

      % Decide if prev_coeffs exists
      has_prev = (n>1);

      % Get the pixel weights
      if (~has_prev)
        se = s;
      else
        se = exp(prev_coeffs(1) + prev_coeffs(2)*z);
      end

      % More precomputing
      se2 = se.^2;
      se2ls = se2 .* ls;

      ss2 = sum(se2);
      szs2 = sum(z.*se2);
      sz2s2 = sum(z2.*se2);

      % The tiny Jacobian matrix
      mat = [ss2  szs2; ...
             szs2 sz2s2];

      % Results
      res = [sum(se2ls); sum(z.*se2ls)];

      % Avoid badly scaled matrix
      rs = rcond(mat);
      if (abs(det(mat)) < 1e-5 || isnan(rs) || abs(rs) < 1e-3)
        coeffs = [-Inf Inf];
        break;
      end

      % Regression
      coeffs = mat \ res;

      % Handle the iterative procedure
      if (has_prev)
        if (sum(abs(coeffs-prev_coeffs))<stop)
          break;
        else
          coeffs = coeffs*(1-weight) + prev_coeffs*weight;
        end
      end

      % Store for the next iteration
      prev_coeffs = coeffs;
    end

    % Extract the parameters
    sigma = sqrt(-1/(2*coeffs(2)));
    ampl = exp(coeffs(1));

    % And store them
    params = [0 0 sigma ampl];

    return;
  end

  function params = regress_2d_amplitudes(s, prev_params)
  % Similar to regress_2d_gaussian but having mu_x and mu_y both equal to 0, and
  % sigma set, leading to the set of equations to be solved to:
  %
  %       J(L-S) = [ 1;    and  V = [ln(s);
  %                  z ]             z*ln(s)]

    % We cannot perform the estimat
    if (numel(prev_params) < 2 || any(~isfinite(prev_params(1:2))) || prev_params(1) == 0)
      params = [0 0 0 0];

      return;
    end

    % Get the good positions
    z = Z(goods);

    % Precompute
    ls = log(s);
    prev_coeffs = [log(prev_params(2)) -(1/(2*prev_params(1)^2))];

    % Get the pixel weights
    se = exp(prev_coeffs(1) + prev_coeffs(2)*z);

    % More precomputing
    se2 = se.^2;
    se2ls = se2 .* ls;

    ss2 = sum(se2);
    szs2 = sum(z.*se2);

    % The tiny Jacobian matrix
    mat = [ss2; ...
           szs2];

    % Results
    res = [sum(se2ls); sum(z.*se2ls)];

    % Avoid badly scaled matrix
    rs = rcond(mat);
    if (abs(det(mat)) < 1e-5 || isnan(rs) || abs(rs) < 1e-3)
      coeffs = [-Inf];
    end

    % Regression
    coeffs = mat \ res;

    % Extract the parameters
    ampl = exp(coeffs(1));

    % And store them
    params = [0 0 prev_params(1) ampl];

    return;
  end


end
