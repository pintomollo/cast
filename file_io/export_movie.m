function export_movie(myrecording, props, opts)
% EXPORT_MOVIE exports an experiment as an AVI movie.
%
%   EXPORT_MOVIE(MYRECORDING, OPTS) exports the channels of MYRECORDING using OPTS and
%   default properties.
%
%   EXPORT_MOVIE(MYRECORDING, PROPS, OPTS) exports MYRECORDING configuring its properties
%   using the correspinding data structure PROPS (get_struct('exporting')).
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 28.08.2014

  % Input checking and default values
  if (nargin < 1)
    return;
  elseif (nargin < 2)
    props = get_struct('exporting');
    opts = get_struct('options');
  elseif (nargin < 3)
    if (isfield(props, 'file_name'))
      opts = get_struct('options');
    else
      opts = props;
      props = get_struct('exporting');
    end
  end

  % Assign the properties locally
  fname = props.file_name;
  low_duplicates = props.low_duplicates;
  cycles_only = props.full_cycles_only;
  show_text = props.movie_show_index;
  show_detect = props.movie_show_detection;
  show_paths = props.movie_show_paths;
  show_reconst = props.movie_show_reconstruction;

  colors = get_struct('colors');

  % Do we have a filename ?
  if (isempty(fname))
    fname = myrecording.experiment;
  end

  % Force to have low duplicates if we want full cycles
  low_duplicates = (low_duplicates || cycles_only);

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
  nchannels = length(myrecording.trackings);

  % Switch to segmentations instead, as there seems to be data in it
  if (nchannels==0 && length(myrecording.segmentations)>0)
    myrecording.trackings = myrecording.segmentations;
    nchannels = length(myrecording.trackings);
  end

  % Loop over all channels
  for i=1:nchannels

    if (isfield(myrecording.trackings(i), 'filtered') && length(myrecording.trackings(i).filtered)>0 && ~all(isnan(myrecording.trackings(i).filtered(1).carth(:))))
      detections = myrecording.trackings(i).filtered;
      is_filtered = true;
    else
      detections = myrecording.trackings(i).detections;
      is_filtered = false;
    end

    segment_type = myrecording.segmentations(i).type;

    % If we want to display the index, we need to reconstruct the tracks
    if (show_text)
      [paths, indexes] = reconstruct_tracks(detections, low_duplicates);
    end

    % Open the specified AVI file with the maximal quality
    movie_name = [fname '_' num2str(i) '.avi'];
    mymovie = VideoWriter(movie_name);
    mymovie.Quality = 100;
    open(mymovie);

    % Get the current number of frames and format the corresponding part of the title
    nframes = length(detections);
    total_str = ['/' num2str(nframes*nchannels)];

    % Loop over all frames
    for nimg = 1:nframes

      % Get the image and the spots
      img = double(load_data(myrecording.channels(i), nimg));
      spots = [detections(nimg).carth detections(nimg).properties];
      if (~is_filtered)
        spots = [spots ones(size(spots, 1), 1)];
      end
      color_index = myrecording.channels(i).color(1);

      % Maybe we need to reconstruct the image
      if (show_reconst)
        %reconstr = reconstruct_detection(img, spots);
        reconstr = perform_step('reconstructing', segment_type, img, spots);

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

        % Use the defined colormap
        colormap(hFig, colors.colormaps{color_index}());
      end

      % Maybe we want to display the paths ?
      if (show_paths)

        % Get the links pointing on the current frame
        links = cellfun(@(x)(x(abs(x(:,end-1)-nimg) < 2,:)), paths, ...
                        'UniformOutput', false);
        links = links(~cellfun('isempty', links));
        lcolors = colorize_graph(links, colors.paths{color_index}(length(links)));

        % And display them
        if (ishandle(hPaths))
          plot_paths(hPaths, links, lcolors);
        else
          hPaths = plot_paths(hAxes, links, lcolors);
        end
      end

      % Maybe we want to display the circles representing the detections
      if (show_detect)
        if (ishandle(hSpots))
          %plot_spots(hSpots, spots);
          perform_step('plotting', segment_type, hSpots, spots, colors.spots{color_index});
        else
          %hSpots = plot_spots(hAxes, spots, colors.spots{color_index});
          hSpots = perform_step('plotting', segment_type, hAxes, spots, colors.spots{color_index});
        end
      end

      % Finally, we might want to display the track index
      if (show_text)

        % We delete all of them every time, maybe faster otherwise ?
        if (ishandle(hText))
          delete(hText);
        end

        % NaN would not be drawn !
        spots(any(isnan(spots), 2),:) = 0;

        % Display the text
        hText = text(spots(:,1), spots(:,2)-6*spots(:,3), num2str(indexes{nimg}), ...
                     'HorizontalAlignment', 'center', 'Color', colors.text{color_index});
      end

      % Update the name as a status bar
      set(hFig, 'Name', [fig_name num2str((nimg+nframes*(i-1))) total_str])

      % Get the current frame and store it in the movie
      frame = getframe(hAxes);
      writeVideo(mymovie, frame);
    end

    % Close the movie
    close(mymovie)
  end

  % Delete the figure
  delete(hFig)

  return;
end
