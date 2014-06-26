function [mytracking] = segment_movie(mytracking, opts)
% SEGMENT_MOVIE segments the various channels of an experiment.
%
%   [MYTRACKING] = SEGMENT_MOVIE(MYTRACKING, OPTS) segments all the channels present
%   in MYTRACKING using the options set in the "segmentations" structure, using the
%   parameter values from OPTS. The resulting detections are stored in "detections"
%   in the corresponding segmentation field.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 26.06.2014

  % A nice status-bar if possible
  if (opts.verbosity > 1)
    hwait = waitbar(0,'','Name','Cell Tracking');
  end

  % Get the number of channels to parse
  nchannels = length(mytracking.channels);

  % Loop over them
  for indx = 1:nchannels

    % Get the current type of segmentation to apply
    type = mytracking.segmentations(indx).type;

    % Check whether it's a spot detection
    is_spot = false;
    switch type
      case 'detect_spots'
        is_spot = true;
      otherwise
        disp(['Warning: segmentation type "' type '" unknown, ignoring.']);
    end

    % Now let's segment this !
    if (is_spot)

      % Get the number of frames
      nframes = size_data(mytracking.channels(indx));

      % Update the waitbar
      if (opts.verbosity > 1)
        waitbar(0, hwait, ['Segmenting channel #' num2str(indx) ': ' mytracking.channels(indx).type]);
      end

      % Prepare the output structure
      detections = get_struct('detection', [1 nchannels]);

      % Iterate over the whole recording
      for nimg = 1:nframes

        % We may need data about the noise
        noise = [];

        % Get the current image
        img = double(load_data(mytracking.channels(indx), nimg));

        % Detrend the image ?
        if (mytracking.segmentations(indx).detrend)
          img = imdetrend(img, opts.segmenting.detrend_meshpoints);
        end

        % Denoise the image ?
        if (mytracking.segmentations(indx).denoise)
          [img, noise] = imdenoise(img, opts.segmenting.denoise_remove_bkg, ...
                          opts.segmenting.denoise_func, opts.segmenting.denoise_size);
        end

        % Segment the image
        spots = detect_spots(img, opts.segmenting.atrous_thresh, ...
                             opts.segmenting.atrous_max_size/opts.pixel_size);

        % Estimate the gaussian parameters for each spot
        spots = estimate_spots(img, spots, opts.segmenting.filter_max_size/(2*opts.pixel_size), ...
                             opts.segmenting.estimate_thresh, ...
                             opts.segmenting.estimate_niter, ...
                             opts.segmenting.estimate_stop, ...
                             opts.segmenting.estimate_weight, ...
                             opts.segmenting.estimate_fit_position);

        % Filter the detected spots ?
        if (mytracking.segmentations(indx).filter_spots)
          if (isempty(noise))
            noise = estimate_noise(img);
          end

          % Build the parameters and filter
          extrema = [opts.segmenting.filter_min_size opts.segmenting.filter_max_size]/...
                     opts.pixel_size;
          spots = filter_spots(spots, extrema, opts.segmenting.filter_min_intensity*noise(2), ...
                                    opts.segmenting.filter_overlap);
        end

        % If we have some detections, store them in the final structure
        if (~isempty(spots))
          detections(nimg).carth = spots(:,1:2);
          detections(nimg).properties = spots(:,3:end);
        end

        % Update the progress bar
        if (opts.verbosity > 1)
          waitbar(nimg/nframes,hwait);
        end
      end

      % Store all detection in the segmentation structure
      mytracking.segmentations(indx).detections = detections;
    end
  end

  % Close the status bar
  if (opts.verbosity > 1)
    close(hwait);
  end

  return;
end
