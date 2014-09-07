function [mytracking] = reestimate_spots(mytracking, img, segmentation, opts)
% REESTIMATE_SPOTS re-estimates the segmentation of the various channels of an
% experiment, taking advantage of the information resulting from the tracking.
%
%   [MYTRACKING] = REESTIMATE_SPOTS(MYTRACKING, OPTS) refines all the channels
%   present in MYTRACKING, when needed, using the options set in the "trackings"
%   structure, using the parameter values from OPTS. The resulting detections are
%   stored back in "detections" in the corresponding segmentation field.
%
%   [SEGMENTATION] = REESTIMATE_SPOTS(SPOTS, IMG, SEGMENTATION, OPTS) performs the TYPE
%   re-estimation in IMG, for the given SPOTS as for SEGMENTATION.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 26.06.2014

  % Input parsing and default values
  do_all = false;
  if (nargin == 2)
    opts = img;
    img = [];
    do_all = true;
    segmentation = [];
  elseif (nargin ~= 4)
     error('Tracking:reestimate_spots', 'Wrong number of inputs, either 2 or 4 accepted');
  end

  % A nice status-bar if possible
  if (opts.verbosity > 1 && do_all)
    hwait = waitbar(0,'','Name','Cell Tracking');
  end

  % Get the number of channels to parse
  if (do_all)
    nchannels = length(mytracking.channels);
  else
    nchannels = 1;
  end

  % Loop over them
  for indx = 1:nchannels

    % Get the current type of segmentation to apply
    if (do_all)
      type = mytracking.segmentations(indx).type;

      % Maybe we do not want to do it...
      if (~mytracking.trackings(indx).reestimate_spots)
        continue
      end
    else
      type = segmentation.type;
    end

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

      if (do_all)
        % Get the number of frames
        nframes = size_data(mytracking.channels(indx));
        frames = [1:nframes];

        % Update the waitbar
        if (opts.verbosity > 1)
          waitbar(0, hwait, ['Reestimating channel #' num2str(indx) ': ' mytracking.channels(indx).type]);
        end

        % Prepare the output structure
        detections = mytracking.trackings(indx).filtered;
      else
        % And in the case we refine only one plane
        frames = [1];
        detections = struct('carth', mytracking(:,1:2), 'properties', mytracking(:,3:end));
      end

      % Iterate over the whole recording
      for nimg = frames

        % First re-estimate the interpolated spots
        nans = isnan(detections(nimg).properties);
        if (any(nans))

          % Which ones ?
          to_refine = any(nans, 2);
          spots = detections(nimg).carth(to_refine,:);

          % Replaces the "a-trous" score
          spots = [spots NaN(size(spots, 1), 1)];

          % We may need data about the noise
          noise = [];

          % Get the current image
          if (do_all)
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
          else
            % Detrend the image ?
            if (segmentation.detrend)
              img = imdetrend(img, opts.segmenting.detrend_meshpoints);
            end

            % Denoise the image ?
            if (segmentation.denoise)
              [img, noise] = imdenoise(img, opts.segmenting.denoise_remove_bkg, ...
                              opts.segmenting.denoise_func, opts.segmenting.denoise_size);
            end
          end

          % Estimate the gaussian parameters for each spot
          spots = estimate_spots(img, spots, opts.segmenting.filter_max_size/(2*opts.pixel_size), ...
                               opts.segmenting.estimate_thresh, ...
                               opts.segmenting.estimate_niter, ...
                               opts.segmenting.estimate_stop, ...
                               opts.segmenting.estimate_weight, ...
                               opts.segmenting.estimate_fit_position);

          % If we have some detections, store them in the final structure
          if (~isempty(spots))
            detections(nimg).carth(to_refine,:) = spots(:,1:2);
            detections(nimg).properties(to_refine,:) = spots(:,3:end);
          end
        end

        % Update the progress bar
        if (opts.verbosity > 1 && do_all)
          waitbar(nimg/nframes,hwait);
        end
      end

      % Store all detection in the tracking structure
      if (do_all)
        mytracking.trackings(indx).filtered = detections;
      else
        mytracking = [detections.carth detections.properties];
      end
    end
  end

  % Close the status bar
  if (opts.verbosity > 1 && do_all)
    close(hwait);
  end

  return;
end
