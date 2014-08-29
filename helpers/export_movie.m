function export_movie(mytracking, varargin)
% EXPORT_MOVIE exports an experiment as an AVI movie.
%
%   EXPORT_MOVIE(MYTRACKING, OPTS) exports the channels of MYTRACKING using OPTS.
%
%   EXPORT_MOVIE(MYTRACKING, LOW_DUPLICATE, OPTS) overlaid to the image, the number of
%   the track obtained with LOW_DUPLICATE corresponding to the cell will be displayed.
%   Providing LOW_DUPLICATE is required for using the SHOW_* options (see below).
%
%   EXPORT_MOVIE(..., FNAME) exorts the movie under the FNAME.
%
%   EXPORT_MOVIE(..., SHOW_DETECTIONS) draws on top of the image the detected radius.
%
%   EXPORT_MOVIE(..., SHOW_DETECTIONS, SHOW_PATHS) draws in addition the links to the
%   previous and next position.
%
%   EXPORT_MOVIE(..., SHOW_DETECTIONS, SHOW_PATHS, SHOW_RECONSTRUCTION) displays next
%   to the raw image, the reconstructed image (slow).
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 28.08.2014

  % Input checking and default values
  fname = mytracking.experiment;
  low_duplicates = [];
  show_detect = [];
  show_paths = [];
  show_reconst = [];
  opts = get_struct('options');

  % Loop over the various inputs and assign them depending on their types
  for i=1:length(varargin)
    if (isstruct(varargin{i}))
      opts = varargin{i};
    elseif (islogical(varargin{i}))
      if (isempty(low_duplicates))
        low_duplicates = varargin{i};
      elseif (isempty(show_detect))
        show_detect = varargin{i};
      elseif (isempty(show_paths))
        show_paths = varargin{i};
      elseif (isempty(show_reconst))
        show_reconst = varargin{i};
      end
    elseif (ischar(varargin{i}) && ~isempty(varargin{i}))
      fname = varargin{i};
    end
  end

  % Do we even need the text ?
  show_text = (~isempty(low_duplicates));

  % Replace empty values
  if (isempty(show_detect))
    show_detect = false;
  end
  if (isempty(show_paths))
    show_paths = false;
  end
  if (isempty(show_reconst))
    show_reconst = false;
  end

  % Check if there is a folder name in the name itself
  [filepath, name, ext] = fileparts(fname);

  % Otherwise, put them into the export directory
  if (isempty(filepath))
    filepath = 'export';
  end

  % Create the directory
  if (~exist(filepath, 'dir'))
    mkdir(filepath);
  end

  % Build the full name
  fname = fullfile(filepath, name);

  % And the figure name
  fig_name = 'Recording video, do not hide this window !! ';

  % Prepare the figure and the axis
  hFig = figure('Visible', 'off', ...
                'NumberTitle', 'off', ...
                'Name', fig_name);

  hAxes = axes('Parent', hFig, ...
               'DataAspectRatio', [1 1 1], ...
               'Visible', 'off',  ...
               'Tag', 'axes');

  % Set up the handlers
  hImg = -1;
  hSpots = -1;
  hText = -1;
  hPaths = -1;

  % Initialize some computer-specific variables required for the conversion
  maxuint = intmax('uint16');

  % Now we loop over all channels
  nchannels = length(mytracking.trackings);
  for i=1:nchannels

    % If we want to display the index, we need to reconstruct the tracks
    if (show_text)
      [paths, indexes] = reconstruct_tracks(mytracking.trackings(i).detections, opts, low_duplicates);
    end

    % Open the specified AVI file with the maximal quality
    movie_name = [fname '_' num2str(i) '.avi'];
    mymovie = VideoWriter(movie_name);
    mymovie.Quality = 100;
    open(mymovie);

    % Get the current number of frames and format the corresponding part of the title
    nframes = length(mytracking.trackings(i).detections);
    total_str = ['/' num2str(nframes*nchannels)];

    % Loop over all frames
    for nimg = 1:nframes

      % Get the image and the spots
      img = double(load_data(mytracking.channels(i), nimg));
      spots = [mytracking.trackings(i).detections(nimg).carth mytracking.trackings(i).detections(nimg).properties];

      % Maybe we need to reconstruct the image
      if (show_reconst)
        reconstr = reconstruct_detection(img, spots);

        % Concatenate them
        img = [img reconstr];
      end

      % We either replace the image or create a new one
      if (ishandle(hImg))
        set(hImg, 'CData', img);
      else

        % We need the image size to set the axes properly
        ssize = size(img);

        % Adapt the size of the image, fix the aspect ratio and the pixel range
        set(hFig, 'Visible', 'on', 'Position', [1 1 ssize([2 1])]);
        hImg = image(img,'Parent', hAxes, 'CDataMapping', 'scaled');
        set(hAxes,'Visible', 'off', 'CLim', [0 maxuint], 'DataAspectRatio',  [1 1 1]);
      end

      % Maybe we want to display the paths ?
      if (show_paths)

        % Get the links pointing on the current frame
        links = cellfun(@(x)(x(abs(x(:,end-1)-nimg) < 2,:)), paths, ...
                        'UniformOutput', false);
        links = links(~cellfun('isempty', links));

        % And display them
        if (ishandle(hPaths))
          plot_paths(hPaths, links);
        else
          hPaths = plot_paths(hAxes, links);
        end
      end

      % Maybe we want to display the circles representing the detections
      if (show_detect)
        if (ishandle(hSpots))
          plot_spots(hSpots, spots);
        else
          hSpots = plot_spots(hAxes, spots);
        end
      end

      % Finally, we might want to display the track index
      if (show_text)

        % We delete all of them every time, maybe faster otherwise ?
        if (ishandle(hText))
          delete(hText);
        end

        % NaN would not be drawn !
        spots(isnan(spots(:,3)),3) = 0;

        % Display the text
        hText = text(spots(:,1), spots(:,2)-3*spots(:,3), num2str(indexes{nimg}), ...
                     'HorizontalAlignment', 'center');
      end

      % Get the current frame and store it in the movie
      frame = getframe(hAxes);
      writeVideo(mymovie, frame);

      % Update the name as a status bar
      set(hFig, 'Name', [fig_name num2str((j+nframes*(i-1))) total_str])
    end

    % Close the movie
    close(mymovie)
  end

  % Delete the figure
  delete(hFig)

  return;
end
