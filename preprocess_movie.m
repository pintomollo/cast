function [mytracking] = preprocess_movie(mytracking, opts)
% PREPROCESS_MOVIE converts the OME-TIFF recordings contained in a tracking structure
% into properly filtered (as defined by the structure, see input_channels.m) UINT16
% files.
%
%   [MYTRACKING] = PREPROCESS_MOVIE(MYTRACKING, OPTS) rescales all the recordings used
%   in the tracking experiement using OPTS.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 18.05.2014

  % Initialize some computer-specific variables required for the conversion
  maxuint = intmax('uint16');

  % A nice status-bar if possible
  if (opts.verbosity > 1)
    hwait = waitbar(0,'','Name','Cell Tracking');
  end

  % Get all the fields of the experiement as this might change based on the data,
  % and loop over them
  fields = fieldnames(mytracking);
  for f = 1:length(fields)
    field = fields{f};

    % If the current field does not contain a file, skip it
    if (~isfield(mytracking.(field), 'fname'))
      continue;
    end

    % Fields can be arrays of structures, so loop over them
    for k = 1:length(mytracking.(field))

      % Stire the original file name as we will replace it by the rescaled one
      mytracking.(field)(k).file = mytracking.(field)(k).fname;

      % Perfom some string formatting for the display
      indx = strfind(mytracking.(field)(k).file, filesep);
      if (isempty(indx))
        indx = 1;
      else
        indx = indx(end) + 1;
      end
      if (opts.verbosity > 1)
        waitbar(0, hwait, ['Preprocessing Movie ' strrep(mytracking.(field)(k).file(indx:end),'_','\_')]);
      end

      fname = absolutepath(mytracking.(field)(k).file);

      % Get the name of the new file
      tmp_fname = absolutepath(get_new_name('tmpmat(\d+)\.ome\.tiff?', 'TmpData'));

      % Get the number of frames
      nframes = size_data(fname);

      % Temporary parameters about the type of data contained in the reader
      img_params = [];

      % Loop over the frames
      for i=1:nframes
        % Convert the image into UINT16
        [img, img_params] = all2uint16(load_data(fname, i), img_params);

        % Perform the required filtering
        if (mytracking.(field)(k).detrend)
          img = imdetrend(img, opts.filtering.detrend_meshpoints);
        end
        if (mytracking.(field)(k).cosmics)
          img = imcosmics(img, opts.filtering.cosmic_rays_window_size, opts.filtering.cosmic_rays_threshold);
        end
        if (mytracking.(field)(k).hot_pixels)
          img = imhotpixels(img, opts.filtering.hot_pixels_threshold);
        end

        % Get the current range of values
        minimg = min(img(:));
        maximg = max(img(:));

        % We'll store the biggest range, to rescale it afterwards
        if(minimg < mytracking.(field)(k).min)
          mytracking.(field)(k).min = minimg;
        end
        if(maximg > mytracking.(field)(k).max)
          mytracking.(field)(k).max = maximg;
        end

        % Save the image in the temporary file
        save_data(tmp_fname, img);

        % Update the progress bar if needed
        if (opts.verbosity > 1)
          if (mytracking.(field)(k).normalize)
            waitbar(i/(2*nframes),hwait);
          else
            waitbar(i/nframes,hwait);
          end
        end
      end

      % Rescale if required by the user
      if (mytracking.(field)(k).normalize)
        % Get a third file to write into
        fname = tmp_fname;
        tmp_fname = absolutepath(get_new_name('tmpmat(\d+)\.ome\.tiff?', 'TmpData'));
        mytracking.(field)(k).fname = tmp_fname;

        % Loop again over the frames
        for i=1:nframes

          % Load and rescale using the previously measured range
          img = load_data(fname, i);
          img = imnorm(img, mytracking.(field)(k).min, mytracking.(field)(k).max, '', 0, maxuint);

          % And save the final image
          save_data(tmp_fname, img);

          % Update the progress bar
          if (opts.verbosity > 1)
            waitbar(0.5 + i/(2*nframes),hwait);
          end
        end

        % Delete the intermidary file (i.e. the filtered one)
        delete(fname);
      else
        mytracking.(field)(k).fname = tmp_fname;
      end
    end
  end

  % Close the status bar
  if (opts.verbosity > 1)
    close(hwait);
  end

  return;
end
