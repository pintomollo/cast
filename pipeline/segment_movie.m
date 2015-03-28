function [myrecording, opts] = segment_movie(myrecording, opts)
% SEGMENT_MOVIE segments the various channels of an experiment.
%
%   [MYRECORDING] = SEGMENT_MOVIE(MYRECORDING, OPTS) segments all the channels present
%   in MYRECORDING using the options set in the "segmentations" structure, using the
%   parameter values from OPTS. The resulting detections are stored in "detections"
%   in the corresponding segmentation field.
%
%   [MYRECORDING, OPTS] = SEGMENT_MOVIE(...) also returns the option structure OPTS.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 26.06.2014

  % A nice status-bar if possible
  if (opts.verbosity > 1)
    hwait = waitbar(0,'','Name','CAST');
  end

  % Get the number of channels to parse
  nchannels = length(myrecording.channels);

  % Loop over them
  for indx = 1:nchannels

    % Get the current type of segmentation to apply
    segment_type = myrecording.segmentations(indx).type;

    % Get the number of frames
    nframes = size_data(myrecording.channels(indx));

    % Prepare the output structure
    detections = get_struct('detection', [1 nframes]);

    %{
    % Check whether it's a spot detection
    switch type
      case {'multiscale_gaussian_spots', 'rectangular_local_maxima'}
        % Let's do this !
      case {'None','none'}
        % Skipping it !
        continue;
      otherwise
        % Unknown...
        disp(['Warning: segmentation type "' type '" unknown, ignoring.']);
        continue;
    end
    %}

    % Update the waitbar
    if (opts.verbosity > 1)
      waitbar(0, hwait, ['Segmenting channel #' num2str(indx) ': ' myrecording.channels(indx).type]);
    end

    % Iterate over the whole recording
    for nimg = 1:nframes

      % We may need data about the noise
      noise = [];

      % Get the current image
      img = double(load_data(myrecording.channels(indx), nimg));

      % Get the noise parameters
      noise = estimate_noise(img);

      % Detrend the image ?
      if (myrecording.segmentations(indx).detrend)
        img = imdetrend(img, opts.segmenting.detrend_meshpoints);
      end

      % Denoise the image ?
      if (myrecording.segmentations(indx).denoise)
        img = imdenoise(img, opts.segmenting.denoise_remove_bkg, ...
                        opts.segmenting.denoise_func, opts.segmenting.denoise_size);
      end

      %{
      switch type
        case 'multiscale_gaussian_spots'
          % Segment the image
          spots = detect_spots(img, opts.segmenting.atrous_thresh, ...
                               opts.segmenting.atrous_max_size/opts.pixel_size);

          % Estimate the gaussian parameters for each spot
          spots = estimate_spots(img, spots, opts.segmenting.atrous_max_size/(2*opts.pixel_size), ...
                               opts.segmenting.estimate_thresh, ...
                               opts.segmenting.estimate_niter, ...
                               opts.segmenting.estimate_stop, ...
                               opts.segmenting.estimate_weight, ...
                               opts.segmenting.estimate_fit_position);

          % Get the Gaussian intensities
          spots_intens = gaussian_intensities(spots);
        case 'rectangular_local_maxima'
          spots = detect_maxima(img, opts.segmenting.maxima_window);
          spots = estimate_window(img, spots, opts.segmenting.maxima_window);
          spots_intens = window_intensities(spots);
      end
      %}

      spots = perform_step('segmentation', segment_type, img, opts);

      % Filter the detected spots ?
      if (myrecording.segmentations(indx).filter_spots)

        spots = perform_step('filtering', segment_type, spots, opts, noise);

        % Build the parameters and filter
        %extrema = [opts.segmenting.filter_min_size opts.segmenting.filter_max_size]/...
        %           opts.pixel_size;
        %spots = filter_spots(spots, spots_intens, extrema, opts.segmenting.filter_min_intensity*noise(2), ...
        %                          opts.segmenting.filter_overlap);
      end

      % If we have some detections, store them in the final structure
      if (~isempty(spots))
        detections(nimg).carth = spots(:,1:2);
        detections(nimg).properties = spots(:,3:end);
      end
      detections(nimg).noise = noise;

      % Update the progress bar
      if (opts.verbosity > 1)
        waitbar(nimg/nframes,hwait);
      end
    end

    % Store all detection in the segmentation structure
    myrecording.segmentations(indx).detections = detections;
  end

  % Close the status bar
  if (opts.verbosity > 1)
    close(hwait);
  end

  return;
end
