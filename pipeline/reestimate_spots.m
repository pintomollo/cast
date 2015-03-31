function [myrecording] = reestimate_spots(myrecording, img, segmentation, opts)
% REESTIMATE_SPOTS re-estimates the segmentation of the various channels of an
% experiment, taking advantage of the information resulting from the tracking.
%
%   [MYRECORDING] = REESTIMATE_SPOTS(MYRECORDING, OPTS) refines all the channels
%   present in MYRECORDING, when needed, using the options set in the "trackings"
%   structure, using the parameter values from OPTS. The resulting detections are
%   then stored in "filtered" in the corresponding segmentation field.
%
%   [SEGMENTATION] = REESTIMATE_SPOTS(SPOTS, IMG, SEGMENTATION, OPTS) performs the
%   re-estimation in IMG, for the given SPOTS as detailed in SEGMENTATION.
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
     error('CAST:reestimate_spots', 'Wrong number of inputs, either 2 or 4 accepted');
  end

  % No data provided
  if (isempty(myrecording))
    return;
  end

  % A nice status-bar if possible
  if (opts.verbosity > 1 && do_all)
    hwait = waitbar(0,'','Name','CAST');
  end

  % Get the number of channels to parse
  if (do_all)
    nchannels = length(myrecording.channels);
  else
    nchannels = 1;
  end

  % Loop over them
  for indx = 1:nchannels

    % Get the current type of segmentation to apply
    if (do_all)
      segment_type = myrecording.segmentations(indx).type;

      % Maybe we do not want to do it...
      if (~myrecording.trackings(indx).reestimate_spots)
        continue
      end

      do_filter = myrecording.segmentations(indx).filter_spots;
    else
      segment_type = segmentation.type;
      do_filter = false;
    end

    % Now let's determine what to segment
    if (do_all)

      % Get the number of frames
      nframes = size_data(myrecording.channels(indx));
      frames = [1:nframes];

      % Update the waitbar
      if (opts.verbosity > 1)
        waitbar(0, hwait, ['Reestimating channel #' num2str(indx) ': ' myrecording.channels(indx).type]);
      end

      % Prepare the output structure
      detections = myrecording.trackings(indx).filtered;
    else
      % And in the case we refine only one plane
      frames = [1];
      detections = struct('carth', myrecording(:,1:2), 'properties', myrecording(:,3:end));
    end

    % Iterate over the whole recording
    for nimg = frames

      % Check whether we have some data to interpolate
      to_refine = logical(detections(nimg).properties(:, end));
      if (any(to_refine))

        % Which ones ?
        spots = [detections(nimg).carth(to_refine,:) ...
                 detections(nimg).properties(to_refine, :)];
        orig_spots = spots;

        % We may need data about the noise
        noise = [];

        % Get the current image
        if (do_all)
          img = double(load_data(myrecording.channels(indx), nimg));

          % Detrend the image ?
          if (myrecording.segmentations(indx).detrend)
            img = imdetrend(img, opts.segmenting.detrend_meshpoints);
          end

          % Denoise the image ?
          if (myrecording.segmentations(indx).denoise)
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
        spots = perform_step('estimation', segment_type, img, orig_spots(:,[1 2]), opts);

        % Filter the detected spots ?
        goods = true(size(spots, 1), 1);
        if (do_filter)

          if (isempty(noise))
            % Get the noise parameters
            noise = estimate_noise(img);
          end

          % Actually filter them
          [junk, goods] = perform_step('filtering', segment_type, spots, opts, noise);

          % Do we need to enforce signal estimation ?
          if (opts.segmenting.force_estimation && any(~goods))

            % Forced estimation for each spot
            spots(~goods,:) = perform_step('estimation', segment_type, img, orig_spots(~goods,1:end-1), opts, true);

            % Final filtering check !
            [junk, goods] = perform_step('filtering', segment_type, spots, opts, noise);
          end
        end

        % Remove the spots that cannot be reestimated from the updated list
        spots = spots(goods,:);
        to_refine(to_refine) = goods;

        % If we have updated some detections, store them in the final structure
        if (~isempty(spots))
          detections(nimg).carth(to_refine,:) = spots(:,1:2);
          detections(nimg).properties(to_refine,1:end-1) = spots(:,3:end);
        end
      end

      % Update the progress bar
      if (opts.verbosity > 1 && do_all)
        waitbar(nimg/nframes,hwait);
      end
    end

    % Store all detection in the tracking structure
    if (do_all)
      myrecording.trackings(indx).filtered = detections;
    else
      myrecording = [detections.carth detections.properties];
    end
    %end
  end

  % Close the status bar
  if (opts.verbosity > 1 && do_all)
    close(hwait);
  end

  return;
end
