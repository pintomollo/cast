function [varargout] = perform_step(cast_step, segment_type, varargin)

  switch cast_step
    case 'display'
    case 'segmentation'

      img = varargin{1};
      opts = varargin{2};
      switch segment_type
        case 'multiscale_gaussian_spots'
          spots = detect_spots(img, opts.segmenting.atrous_thresh, ...
                               opts.segmenting.atrous_max_size/opts.pixel_size);
          spots = estimate_spots(img, spots, opts.segmenting.atrous_max_size/(2*opts.pixel_size), ...
                               opts.segmenting.estimate_thresh, ...
                               opts.segmenting.estimate_niter, ...
                               opts.segmenting.estimate_stop, ...
                               opts.segmenting.estimate_weight, ...
                               opts.segmenting.estimate_fit_position);
        case 'rectangular_local_maxima'
          spots = detect_maxima(img, opts.segmenting.maxima_window);
          spots = estimate_window(img, spots, opts.segmenting.maxima_window);
        otherwise
          spots = [];
          %disp('No segmentation')
      end
      varargout = {spots};

    case 'intensity'

      spots = varargin{1};
      % Compute the signal intensities
      switch segment_type
        case 'multiscale_gaussian_spots'
          spots_intens = intensity_gaussians(spots);
        case 'rectangular_local_maxima'
          spots_intens = intensity_windows(spots);
        otherwise
          spots_intens = [];
          %disp('No segmentation')
      end
      varargout = {spots_intens};

    case 'filtering'

      spots = varargin{1};
      opts = varargin{2};
      noise = varargin{3};
      % Compute the signal intensities
      switch segment_type
        case 'multiscale_gaussian_spots'
          spots_intens = intensity_gaussians(spots);
          extrema = [opts.segmenting.filter_min_size / opts.pixel_size, ...
                     opts.segmenting.filter_min_intensity*noise(2); ...
                     opts.segmenting.filter_max_size / opts.pixel_size, Inf];
          fusion = @fuse_gaussians;
        case 'rectangular_local_maxima'
          spots_intens = intensity_windows(spots);
          extrema = [opts.segmenting.filter_min_size / opts.pixel_size, ...
                     opts.segmenting.filter_min_intensity*noise(2); ...
                     opts.segmenting.filter_max_size / opts.pixel_size, Inf];
          if (size(extrema, 2) < 3)
            extrema = extrema(:, [1 1:end]);
          end
          fusion = @fuse_windows;
        otherwise
          spots = [];
          spots_intens = [];
          fusion = [];
          %disp('No segmentation')
      end
      filtered = filter_spots(spots, spots_intens, fusion, extrema, ...
                              opts.segmenting.filter_overlap);
      varargout = {filtered};

    case 'reconstructing'

      orig_img = varargin{1};
      spots = varargin{2};
      % Compute the signal intensities
      switch segment_type
        case 'multiscale_gaussian_spots'
          draw = @(params,ssize)(GaussMask2D(params(3), ssize, params([2 1]), 0, 1) * params(4));
        case 'rectangular_local_maxima'
          draw = @draw_window;
        otherwise
          draw = [];
          spots = [];
          %disp('No segmentation')
      end
      img = reconstruct_detection(orig_img, real(spots), draw);
      varargout = {img};

    case 'plotting'

      handle = varargin{1};
      spots = varargin{2};
      colors = varargin{3};
      % Compute the signal intensities
      switch segment_type
        case 'multiscale_gaussian_spots'
          hgroup = plot_gaussians(handle, spots, colors);
        case 'rectangular_local_maxima'
          hgroup = plot_windows(handle, spots, colors);
        otherwise
          if (strncmp(get(handle, 'Type'), 'hggroup',7))
            hgroup = handle;
          else
            hgroup = hggroup('Parent', handle);
          end
          %disp('No segmentation')
      end
      varargout = {hgroup};

    case 'exporting'
    otherwise
      varargout = {};
  end

  return;
end
