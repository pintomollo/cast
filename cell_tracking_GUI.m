function [mytracking, opts] = cell_tracking_GUI(mytracking, opts)
% CELL_TRACKING_GUI displays the main window for the interactive tracking of
% recordings.
%
%   [MYTRACKING, OPTS] = CELL_TRACKING_GUI(MYTRACKING,OPTS) displays the window using
%   the data contained in MYTRACKING and the parameter values from OPTS. It updates
%   them accordingly to the user's choice. MYTRACKING should be a 'mytracking'
%   structure as produced by get_struct('mytracking')
%
%   [...] = CELL_TRACKING_GUI() displays an empty GUI for the user to load a 
%   recording interactively.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 02.07.2014

  % Argument checking, need to know if we ask for a mytracking file or not.
  if (nargin ~= 2 | isempty(mytracking) | isempty(opts))
    mytracking = get_struct('myrecording');
    opts = get_struct('options');
  else
    opts = update_structure(opts, 'options');
  end

  % Prepare some global variables
  channels = mytracking.channels;
  nchannels = length(channels);
  nframes = 1;
  segmentations = mytracking.segmentations;
  trackings = mytracking.trackings;
  has_segmentation = false;
  autosave = true;
  colors = get_struct('colors');
  color_index = 1;

  % Dragzoom help message
  imghelp = ['DRAGZOOM interactions (help dragzoom):\n\n', ...
  '###Normal mode:###\n', ...
  'single-click and holding LB : Activation Drag mode\n', ...
  'single-click and holding RB : Activation Rubber Band for region zooming\n', ...
  'single-click MB             : Activation ''Extend'' Zoom mode\n', ...
  'scroll wheel MB             : Activation Zoom mode\n', ...
  'double-click LB, RB, MB     : Reset to Original View\n\n', ...
  ' \n', ...
  '###Magnifier mode:###\n', ...
  'single-click LB             : Not Used\n', ...
  'single-click RB             : Not Used\n', ...
  'single-click MB             : Reset Magnifier to Original View\n', ...
  'scroll MB                   : Change Magnifier Zoom\n', ...
  'double-click LB             : Increase Magnifier Size\n', ...
  'double-click RB             : Decrease Magnifier Size\n', ...
  ' \n', ...
  '###Hotkeys in 2D mode:###\n', ...
  '''+''                         : Zoom plus\n', ...
  '''-''                         : Zoom minus\n', ...
  '''0''                         : Set default axes (reset to original view)\n', ...
  '''uparrow''                   : Up or down (inrerse) drag\n', ...
  '''downarrow''                 : Down or up (inverse) drag\n', ...
  '''leftarrow''                 : Left or right (inverse) drag\n', ...
  '''rightarrow''                : Right or left (inverse) drag\n', ...
  '''c''                         : On/Off Pointer Symbol ''fullcrosshair''\n', ...
  '''g''                         : On/Off Axes Grid\n', ...
  '''x''                         : If pressed and holding, zoom and drag works only for X axis\n', ...
  '''y''                         : If pressed and holding, zoom and drag works only for Y axis\n', ...
  '''m''                         : If pressed and holding, Magnifier mode on\n', ...
  '''l''                         : On/Off Synchronize XY manage of 2-D axes\n', ...
  '''control+l''                 : On Synchronize X manage of 2-D axes\n', ...
  '''alt+l''                     : On Synchronize Y manage of 2-D axes\n', ...
  '''s''                         : On/Off Smooth Plot (Experimental)'];

  % Create the GUI using segmentations
  [hFig, handles] = create_figure();

  % And setup the environment for the recording
  setup_environment()

  % Allocate the various images. This allows them to be "persistent" between
  % different calls to the callback functions.
  orig_img = [];
  img_next = [];
  spots = [];
  spots_next = [];
  all_paths = [];
  paths = [];
  all_colors = [];
  is_updated = true;
  paths = [];

  % Display the figure
  set(hFig,'Visible', 'on');
  % Update its content
  update_display;
  % And wait until the user is done
  uiwait(hFig);

  % Store the segmentations
  mytracking.segmentations = segmentations;
  % And get the experiment name
  if (nchannels > 0)
    mytracking.experiment = get(handles.experiment, 'String');
  end

  % Delete the whole figure
  delete(hFig);
  drawnow;

  return;

  function setup_environment()

    channels = mytracking.channels;
    nchannels = length(channels);
    segmentations = mytracking.segmentations;
    trackings = mytracking.trackings;

    % Initialize the structure used for the interface
    liststring = '';
    for i = 1:nchannels

      % Build the displayed list
      liststring = [liststring channels(i).type num2str(i)];
      if (i < nchannels)
        liststring = [liststring '|'];
      end
    end

    % Get the number of frames
    if nchannels > 0
      nframes = size_data(channels(1).fname);
    else
      nframes = NaN;
    end

    % And the experiment name
    exp_name = mytracking.experiment;
    if (isempty(exp_name))
      exp_name = 'Load a recording here -->';
    end

    if isfinite(nframes)
      slider_step = [1 10]/nframes;
      slider_max = max(nframes, 1.1);
      slider_min = 1;
    else
      slider_step = [1 1];
      slider_max = 1.1;
      slider_min = 1;
    end

    if (nchannels > 0)
      panel_title = [channels(i).type '1'];
    else
      panel_title = '';
    end

    set(handles.list, 'String', liststring);
    set(handles.experiment, 'String', exp_name);

    set(handles.slider1, 'SliderStep', slider_step, 'Max', slider_max, 'Min', slider_min, 'Value', 1);
    set(handles.slider2, 'SliderStep', slider_step, 'Max', slider_max, 'Min', slider_min, 'Value', 1);
    set(handles.text1, 'String', 'Frame #1');
    set(handles.text2, 'String', 'Frame #1');

    set(handles.uipanel, 'Title', panel_title);

    handles.prev_frame = [-1 -1];
    handles.frame = [1 1];
    handles.prev_channel = -1;
    handles.current = 1;

    if (nchannels == 0)
      set(handles.save, 'Enable', 'off');
      set(handles.pipeline(2:end), 'Enable', 'off')
      set(handles.pipeline(1), 'String', 'Load Recording')
    else
      set(handles.save, 'Enable', 'on');
      set(handles.pipeline, 'Enable', 'on');
      set(handles.pipeline(1), 'String', 'Process Recording')

      if (isempty(segmentations))
        set(handles.pipeline(3:end), 'Enable', 'off')
      else
        has_tracking = false;
        for j=1:nchannels
          for i=1:nframes
            if (~isempty(segmentations(j).detections(i).cluster))
              has_tracking = true;
              break;
            end
          end
          if has_tracking
            break;
          end
        end

        if (~has_tracking)
          set(handles.pipeline(end), 'Enable', 'off')
        end
      end
    end

    return;
  end

  function update_display(recompute)
  % The main figure of the GUI, the one responsible for the proper display
  % of its content.

    % By default we recompute everything
    if (nargin == 0)
      recompute = true;
    end

    % Get the indexes of the current frame and channel
    indx = handles.current;
    nimg = handles.frame;

    % Stop if no data at all
    if (indx < 1 || indx > nchannels)

      if (numel(handles.img) > 1 & all(ishandle(handles.img)))
        set(handles.img(1),'CData', []);
        set(handles.img(2),'CData', []);

        plot_paths(handles.data(3), {[]});
        plot_paths(handles.data(4), {[]});

        plot_spots(handles.data(1), []);
        plot_spots(handles.data(2), []);
      end

      return;
    end

    % If we have changed channel, we need to update the display of the buttons
    if (indx ~= handles.prev_channel && indx <= nchannels)
      % Because it takes long, display it and block the GUI
      color_index = channels(indx).color(1);
      set(hFig, 'Name', 'Cell Tracking Platform (Processing...)');
      all_all = [handles.all_buttons, handles.save, handles.pipeline];
      curr_status = get(all_all, 'Enable');
      set(all_all, 'Enable', 'off');
      drawnow;
      refresh(hFig);

      has_segmentation = false;

      % The name
      set(handles.uipanel,'Title', [channels(indx).type ' ' num2str(indx)]);

      % And setup the indexes correctly
      handles.prev_channel = indx;
      handles.prev_frame = [-1 -1];

      % The paths
      if (~isempty(trackings))
        has_segmentation = true;
        all_paths = reconstruct_tracks(trackings(indx).detections, true);
      elseif (~isempty(segmentations) && length(segmentations(indx).detections)==nframes)
        has_segmentation = true;
        has_tracking = false;
        for i=1:nframes
          if (~isempty(segmentations(indx).detections(i).cluster))
            has_tracking = true;
            break;
          end
        end

        if has_tracking
          all_paths = reconstruct_tracks(segmentations(indx).detections, true);
        else
          all_paths = [];
        end
      else
        all_paths = [];
      end

      set(hFig, 'Name', 'Cell Tracking Platform');
      set(all_all, {'Enable'}, curr_status);
    end
    all_colors = colorize_graph(all_paths, colors.paths{color_index}(length(all_paths)));

    % The slider
    set(handles.text1, 'String', ['Frame #' num2str(nimg(1))]);
    set(handles.text2, 'String', ['Frame #' num2str(nimg(2))]);

    if (recompute)
      % Because it takes long, display it and block the GUI
      set(hFig, 'Name', 'Cell Tracking Platform (Processing...)');
      curr_status = get(handles.all_buttons, 'Enable');
      set(handles.all_buttons, 'Enable', 'off');
      drawnow;
      refresh(hFig);

      % Here we recompute all the filtering of the frame
      noise = [];

      % Try to avoid reloading frames as much as possible
      if (nimg(1) == handles.prev_frame(1))
        if (nimg(2) == nimg(1))
          img_next = orig_img;
        else
          img_next = double(load_data(channels(indx).fname, nimg(2)));
        end
      elseif (nimg(2) == handles.prev_frame(2))
        if (nimg(2) == nimg(1))
          orig_img = img_next;
        else
          orig_img = double(load_data(channels(indx).fname, nimg(1)));
        end
      else
        if (nimg(2) == nimg(1))
          orig_img = double(load_data(channels(indx).fname, nimg(1)));
          img_next = orig_img;
        else
          orig_img = double(load_data(channels(indx).fname, nimg(1)));
          img_next = double(load_data(channels(indx).fname, nimg(2)));
        end
      end

      % Update the index
      handles.prev_frame = nimg;
    end

    if (~isempty(all_paths))
      spots = cellfun(@(x)(x(x(:,end-1)==nimg(1),:)), all_paths, 'UniformOutput', false);
      spots = cat(1,spots{:});

      spots_next = cellfun(@(x)(x(x(:,end-1)==nimg(2),:)), all_paths, 'UniformOutput', false);
      spots_next = cat(1,spots_next{:});
    elseif has_segmentation
      spots = [segmentations(indx).detections(nimg(1)).carth segmentations(indx).detections(nimg(1)).properties];
      spots_next = [segmentations(indx).detections(nimg(2)).carth segmentations(indx).detections(nimg(2)).properties];

      spots = spots(all(~isnan(spots),2),:);
      spots_next = spots_next(all(~isnan(spots_next),2),:);

      spots = [zeros(size(spots, 1), 1) spots];
      spots_next = [zeros(size(spots_next, 1), 1) spots_next];
    end

    % Determine which image to display in the left panel
    switch handles.display(1)

      % The reconstructed image
      case 2
        if (~isempty(spots))
          spots1 = spots(:,2:end);
        else
          spots1 = [];
        end
        links1 = {[]};
        colors1 = [];
        divisions_colors1 = colors.spots{color_index};

      % The reconstructed image
      case 3
        if (~isempty(spots))
          divs = spots(:,1);
          spots1 = {spots(divs<0,2:end), spots(divs==0,2:end), spots(divs>0,2:end)};
        else
          spots1 = {[]};
        end
        if (~isempty(all_paths))
          links1 = cellfun(@(x)(x(abs(x(:,end-1)-nimg(1)) < 2,:)), all_paths, 'UniformOutput', false);
          links1 = links1(~cellfun('isempty', links1));
        else
          links1 = {[]};
        end
        colors1 = colorize_graph(links1, colors.paths{color_index}(length(links1)));
        divisions_colors1 = colors.status{color_index};

      % The difference between filtered and reconstructed
      case 4
        if (~isempty(spots))
          divs = spots(:,1);
          spots1 = {spots(divs<0,2:end), spots(divs==0,2:end), spots(divs>0,2:end)};
        else
          spots1 = {[]};
        end
        links1 = all_paths;
        colors1 = all_colors;
        divisions_colors1 = colors.status{color_index};

      % The filtered image
      otherwise
        spots1 = {[]};
        links1 = {[]};
        colors1 = 'k';
        divisions_colors1 = 'k';
    end

    % Determine which image to display in the right panel
    switch handles.display(2)

      % The reconstructed image
      case 2
        if (~isempty(spots_next))
          spots2 = spots_next(:,2:end);
        else
          spots2 = [];
        end
        links2 = {[]};
        colors2 = [];
        divisions_colors2 = colors.spots_next{color_index};

      % The reconstructed image
      case 3
        if (~isempty(spots_next))
          divs = spots_next(:,1);
          spots2 = {spots_next(divs<0,2:end), spots_next(divs==0,2:end), spots_next(divs>0,2:end)};
        else
          spots2 = {[]};
        end
        if (~isempty(all_paths))
          links2 = cellfun(@(x)(x(abs(x(:,end-1)-nimg(2)) < 2,:)), all_paths, 'UniformOutput', false);
          links2 = links2(~cellfun('isempty', links2));
        else
          links2 = {[]};
        end
        colors2 = colorize_graph(links2, colors.paths{color_index}(length(links2)));
        divisions_colors2 = colors.status{color_index};

      % The difference between filtered and reconstructed
      case 4
        if (~isempty(spots_next))
          divs = spots_next(:,1);
          spots2 = {spots_next(divs<0,2:end), spots_next(divs==0,2:end), spots_next(divs>0,2:end)};
        else
          spots2 = {[]};
        end
        links2 = all_paths;
        colors2 = all_colors;
        divisions_colors2 = colors.status{color_index};

      % The filtered image
      otherwise
        spots2 = {[]};
        links2 = {[]};
        colors2 = 'k';
        divisions_colors2 = 'k';
    end

    % If we have already created the axes and the images, we can simply change their
    % content (i.e. CData)
    if (numel(handles.img) > 1 & all(ishandle(handles.img)))
      set(handles.img(1),'CData', orig_img);
      set(handles.img(2),'CData', img_next);

      plot_paths(handles.data(3), links1, colors1);
      plot_paths(handles.data(4), links2, colors2);

      plot_spots(handles.data(1), spots1, divisions_colors1, iscell(spots1));
      plot_spots(handles.data(2), spots2, divisions_colors2, iscell(spots2));
    else

      % Otherwise, we create the two images in their respective axes
      handles.img = image(orig_img,'Parent', handles.axes(1),...
                        'CDataMapping', 'scaled',...
                        'Tag', 'image');
      handles.img(2) = image(img_next,'Parent', handles.axes(2), ...
                        'CDataMapping', 'scaled',...
                        'Tag', 'image');

      % Hide the axes and prevent a distortion of the image due to stretching
      set(handles.axes,'Visible', 'off',  ...
                 'DataAspectRatio',  [1 1 1]);

      % Now add the links
      handles.data(3) = plot_paths(handles.axes(1), links1, colors1);
      handles.data(4) = plot_paths(handles.axes(2), links2, colors2);

      % And their detected spots
      handles.data(1) = plot_spots(handles.axes(1), spots1, divisions_colors1, iscell(spots1));
      handles.data(2) = plot_spots(handles.axes(2), spots2, divisions_colors2, iscell(spots2));

      % Drag and Zoom library from Evgeny Pr aka iroln
      dragzoom(handles.axes, 'on')
    end
    colormap(hFig, colors.colormaps{color_index}());

    if (recompute)
      % Release the image
      set(hFig, 'Name', 'Cell Tracking Platform');
      set(handles.all_buttons, {'Enable'}, curr_status);
    end

    return
  end

  function experiment_Callback(hObject, eventdata)
  % This function is responsible for handling the content of the
  % structure which contains the parameters of the filtering algorithms.

    % Block the GUI
    set(handles.all_buttons, 'Enable', 'off');
    set(handles.save, 'Enable', 'off');
    set(handles.pipeline, 'Enable', 'off')
    drawnow;
    refresh(hFig);

    % And get the type of button which called the callback (from its tag)
    type = get(hObject, 'tag');

    % By default, recompute
    recompute = true;

    % Handle all three buttons differently
    switch type

      % Call the loading function
      case 'load'

        if (nchannels > 0)
          answer = questdlg('Save the current project ?', 'Save ?');
          if (strcmp(answer, 'Yes'))
            uisave({'mytracking','opts'}, [mytracking.experiment '.mat'])
          end
        end

        % Fancy output
        disp('[Select a MAT file]');

        % Prompting the user for the MAT file
        [fname, dirpath] = uigetfile({'*.mat'}, ['Load a MAT file']);

        % Not cancelled
        if (~all(fname == 0));

          fname = fullfile(dirpath, fname);

          % Load the matrix and check its content
          data = load(fname);

          % Not what we expected
          if (~isfield(data, 'mytracking') || ~isfield(data, 'opts'))
            disp(['Error: ' fname ' does not contain a valid mytracking structure']);

          % Extract the loaded data
          else
            mytracking = data.mytracking;
            opts = update_structure(data.opts, 'options');
          end
        end

      % Call the saving function
      case 'save'
        uisave({'mytracking','opts'}, [mytracking.experiment '.mat'])
        recompute = false;

      % Export the results
      case 'export'
        props = get_struct('exporting');
        props.file_name = mytracking.experiment;
        mytracking.channels = channels;

        [props, do_export] = edit_options(props);
        if (do_export)
          if (props.export_data)
            export_tracking(mytracking, props.file_name, props.low_duplicates, ...
                            props.data_aligning_type, opts);
          end
          if (props.export_movie)
            if (~props.movie_show_index)
              export_movie(mytracking, props.file_name, opts);
            else
              export_movie(mytracking, props.file_name, props.low_duplicates, ...
                             props.movie_show_detection, props.movie_show_paths, ...
                             props.movie_show_reconstruction, opts);
            end
          end
        end
        recompute = false;
    end

    % Release the GUI and recompute the filters
    setup_environment()
    set(handles.all_buttons, 'Enable', 'on');
    update_display(recompute);

    return
  end

  function options_Callback(hObject, eventdata)
  % This function is responsible for handling the content of the
  % structure which contains the parameters of the filtering algorithms.

    % Block the GUI
    set(handles.all_buttons, 'Enable', 'off');
    drawnow;
    refresh(hFig);

    % And get the type of button which called the callback (from its tag)
    type = get(hObject, 'tag');

    % By default, recompute
    recompute = true;

    % Handle all three buttons differently
    switch type

      % Call the editing function
      case 'edit'
        [opts, recompute] = edit_options(opts);

      % Call the loading function
      case 'load'
        opts = load_parameters(opts);

      % Call the saving function
      case 'save'
        save_parameters(opts);
        recompute = false;
    end

    % Release the GUI and recompute the filters
    set(handles.all_buttons, 'Enable', 'on');
    setup_environment()
    update_display(recompute);

    return
  end

  function pipeline_Callback(hObject, eventdata)
  % This function is responsible for handling the content of the
  % structure which contains the parameters of the filtering algorithms.

    % Block the GUI
    set(handles.all_buttons, 'Enable', 'off');
    drawnow;
    refresh(hFig);

    % And get the type of button which called the callback (from its tag)
    type = get(hObject, 'tag');

    % By default, recompute
    reload = true;

    % Handle all three buttons differently
    switch type

      % Call the editing function
      case 'new'
        mytracking = get_struct('myrecording');
        opts = get_struct('options');

      % Call the loading function
      case 'process'
        set(hFig, 'Visible', 'off')
        [mytracking, opts, reload] = inspect_recording(mytracking, opts);
        if (reload)
          [mytracking, opts] = preprocess_movie(mytracking, opts);
          if (autosave)
            save([mytracking.experiment '.mat'], 'mytracking', 'opts');
          end
          [opts, recompute] = edit_options(opts);
        end
        set(hFig, 'Visible', 'on')

      % Call the saving function
      case 'segment'
        set(hFig, 'Visible', 'off')
        [mytracking, opts, reload] = inspect_segmentation(mytracking, opts);
        if (reload)
          [mytracking, opts] = segment_movie(mytracking, opts);
          if (autosave)
            save([mytracking.experiment '.mat'], 'mytracking', 'opts');
          end
        end
        set(hFig, 'Visible', 'on')

      % Call the saving function
      case 'track'
        set(hFig, 'Visible', 'off')
        [mytracking, opts, reload] = inspect_tracking(mytracking, opts);
        if (reload)
          [mytracking, opts] = track_spots(mytracking, opts);
          if (autosave)
            save([mytracking.experiment '.mat'], 'mytracking', 'opts');
          end
        end
        set(hFig, 'Visible', 'on')

      % Call the saving function
      case 'paths'
        set(hFig, 'Visible', 'off')
        [mytracking, opts, reload] = inspect_paths(mytracking, opts);
        if (reload)
          [mytracking, opts] = filter_paths(mytracking, opts);
          if (autosave)
            save([mytracking.experiment '.mat'], 'mytracking', 'opts');
          end
        end
        set(hFig, 'Visible', 'on')
    end

    % Release the GUI and recompute the filters
    set(handles.all_buttons, 'Enable', 'on');
    if (reload)
      setup_environment()
    end
    update_display(reload);

    return
  end

  function gui_Callback(hObject, eventdata)
  % This function handles the callback of most buttons in the GUI !

    % By default we recompute the filter
    recompute = true;

    % Get the channel index
    indx = handles.current;

    % If no more data, do nothing
    if (indx < 1)
      return;
    end

    % And get the type of button which called the callback (from its tag)
    type = get(hObject, 'tag');
    switch type

      % Each checkbox is responsible for its respective boolean fields
      case 'autosave'
        autosave = logical(get(hObject, 'Value'));

      % The slider varies the frame index
      case {'slider1','slider2'}
        tmp_indx = str2double(type(end));
        handles.frame(tmp_indx) = round(get(hObject, 'Value'));

      % The radio buttons have the index of their respective choice encoded
      % in their tag (e.g. radioXY). However, because all the iamges are stored
      % we do not need to recompute anything !
      case 'radio'
        tmp_tag = get(eventdata.NewValue, 'tag');
        handles.display(str2double(tmp_tag(end-1))) = [str2double(tmp_tag(end))];
        recompute = false;

      % A change in the channel index
      case 'channels'
        handles.current = get(hObject, 'Value');

      % Call the color gui
      case 'color'
        [tmp_index, recompute] = gui_colors(color_index);
        if (recompute)
          color_index = tmp_index;
          channels(indx).color = color_index;
        end

      % Otherwise, do nothing. This is used to cancel the deletion requests
      otherwise
        return;
    end

    % Update the display accordingly
    update_display(recompute);

    return
  end

  function channel_CloseRequestFcn(hObject, eventdata)
  % This function converts the various indexes back into strings to prepare
  % the segmentations structure for its standard form.

    mytracking.channels = channels;
    if (nchannels > 0)
      answer = questdlg('Save the current project ?', 'Save ?');
      if (strcmp(answer, 'Yes'))
        uisave({'mytracking','opts'}, [mytracking.experiment '.mat'])
      end
    end

    uiresume(hFig);

    return
  end

  function [hFig, handles] = create_figure
  % This function actually creates the GUI, placing all the elements
  % and linking the calbacks.

    % Create my own grayscale map for the image display
    mygray = [0:255]' / 255;
    mygray = [mygray mygray mygray];

    % We build a list of all buttons to easily block and release them
    enabled = [];

    % The main figure, cannot be rescaled, closed nor deleted
    hFig = figure('PaperUnits', 'centimeters',  ...
                  'CloseRequestFcn', @channel_CloseRequestFcn, ...
                  'Color',  [0.7 0.7 0.7], ...
                  'Colormap', mygray, ...
                  'MenuBar', 'none',  ...
                  'Name', 'Cell Tracking Plateform',  ...
                  'NumberTitle', 'off',  ...
                  'Units', 'normalized', ...
                  'Position', [0 0 1 1], ...
                  'DeleteFcn', @gui_Callback, ...
                  'HandleVisibility', 'callback',  ...
                  'Tag', 'channel_fig',  ...
                  'UserData', [], ...
                  'Visible', 'off');

    %%%%%% Now the buttons around the main panel

    % The list of channels
    hChannel = uicontrol('Parent', hFig, ...
                         'Units', 'normalized',  ...
                         'Callback', @gui_Callback, ...
                         'Position', [0.01 0.11 0.1 0.79], ...
                         'String', '', ...
                         'Style', 'listbox',  ...
                         'Value', 1, ...
                         'Tag', 'channels');
    enabled = [enabled hChannel];

    % The OK button
    hOK = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @channel_CloseRequestFcn, ...
                    'Position', [0.90 0.02 0.08 0.05], ...
                    'String', 'OK',  ...
                    'Tag', 'pushbutton11');
    enabled = [enabled hOK];

    % The experiment name and its labels
    hText = uicontrol('Parent', hFig, ...
                      'Units', 'normalized',  ...
                      'Position', [0.2 0.93 0.09 0.025], ...
                      'String', 'Experiment name:',  ...
                      'TooltipString', sprintf(imghelp), ...
                      'BackgroundColor', get(hFig, 'Color'), ...
                      'FontSize', 12, ...
                      'Style', 'text',  ...
                      'Tag', 'text1');

    hName = uicontrol('Parent', hFig, ...
                      'Units', 'normalized',  ...
                      'Position', [0.3 0.93 0.5 0.05], ...
                      'String', 'Load a recording here -->', ...
                      'FontSize', 12, ...
                      'Style', 'edit',  ...
                      'Tag', 'experiment');
    enabled = [enabled hName];

    % The Load/Save buttons
    hLoadExp = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @experiment_Callback, ...
                    'Position', [0.81 0.93 0.06 0.05], ...
                    'String', 'Load',  ...
                    'Tag', 'load');
    enabled = [enabled hLoadExp];
    hSaveExp = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @experiment_Callback, ...
                    'Position', [0.87 0.93 0.06 0.05], ...
                    'String', 'Save',  ...
                    'Tag', 'save');
    hExport = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @experiment_Callback, ...
                    'Position', [0.93 0.93 0.06 0.05], ...
                    'String', 'Export',  ...
                    'Tag', 'export');


    % The sliders and their labels
    hIndex1 = uicontrol('Parent', hFig, ...
                      'Units', 'normalized',  ...
                      'Position', [0.1 0.03 0.08 0.025], ...
                      'String', 'Frame #1',  ...
                      'BackgroundColor', get(hFig, 'Color'), ...
                      'FontSize', 12, ...
                      'Style', 'text',  ...
                      'Tag', 'text1');

    slider_step = [1 1];
    slider_max = 1;
    slider_min = 0;

    hFrame1 = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @gui_Callback, ...
                    'Position', [0.19 0.03 0.28 0.025], ...
                    'Value', 1, ...
                    'SliderStep', slider_step, ...
                    'Max', slider_max, ...
                    'Min', slider_min, ...
                    'Style', 'slider', ...
                    'Tag', 'slider1');
    enabled = [enabled hFrame1];

    hIndex2 = uicontrol('Parent', hFig, ...
                      'Units', 'normalized',  ...
                      'Position', [0.49 0.03 0.08 0.025], ...
                      'String', 'Frame #1',  ...
                      'BackgroundColor', get(hFig, 'Color'), ...
                      'FontSize', 12, ...
                      'Style', 'text',  ...
                      'Tag', 'text2');

    hFrame2 = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @gui_Callback, ...
                    'Position', [0.58 0.03 0.28 0.025], ...
                    'Value', 1, ...
                    'SliderStep', slider_step, ...
                    'Max', slider_max, ...
                    'Min', slider_min, ...
                    'Style', 'slider', ...
                    'Tag', 'slider2');
    enabled = [enabled hFrame2];

    %%%%%%% Now the main panel

    % The panel itsel
    hPanel = uipanel('Parent', hFig, ...
                     'Title', '',  ...
                     'Tag', 'uipanel',  ...
                     'Clipping', 'on',  ...
                     'Position', [0.12 0.11 0.87 0.8]);

    % The two axes
    hAxes = axes('Parent', hPanel, ...
                 'Position', [0 0.1 0.43 0.9], ...
                 'DataAspectRatio', [1 1 1], ...
                 'Visible', 'off',  ...
                 'Tag', 'axes');

    hAxesNext = axes('Parent', hPanel, ...
                 'Position', [0.44 0.1 0.43 0.9], ...
                 'DataAspectRatio', [1 1 1], ...
                 'Visible', 'off',  ...
                 'Tag', 'axes');

    % The two radio button groups that handle which image to display
    % For the choices to be mutually exclusive, one has to put them inside
    % such uibuttongroup.
    hRadio = uibuttongroup('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'SelectionChangeFcn', @gui_Callback, ...
                         'Position', [0 0.05 0.43 0.05], ...
                         'tag', 'radio');

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.02 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Image', ...
                         'Tag', 'radio11');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.27 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Detections', ...
                         'Tag', 'radio12');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.53 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Links', ...
                         'Tag', 'radio13');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.78 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Paths', ...
                         'Tag', 'radio14');
    enabled = [enabled hControl];

    % The second group
    hRadio = uibuttongroup('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'SelectionChangeFcn', @gui_Callback, ...
                         'Position', [0.44 0.05 0.43 0.05], ...
                         'tag', 'radio');

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.02 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Image', ...
                         'Tag', 'radio21');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.27 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Detections', ...
                         'Tag', 'radio22');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.53 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Links', ...
                         'Tag', 'radio23');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.78 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Paths', ...
                         'Tag', 'radio24');
    enabled = [enabled hControl];

    % The New/Filter/Segment/Track buttons
    hNew = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Callback', @pipeline_Callback, ...
                    'Position', [0.89 0.88 0.09 0.06], ...
                    'String', 'New Experiment',  ...
                    'Tag', 'new');
    enabled = [enabled hNew];

    hProcess = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Callback', @pipeline_Callback, ...
                    'Position', [0.89 0.78 0.09 0.06], ...
                    'String', 'Load Recording',  ...
                    'Tag', 'process');
    enabled = [enabled hProcess];

    hSegment = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Callback', @pipeline_Callback, ...
                    'Position', [0.89 0.72 0.09 0.06], ...
                    'String', 'Segment Recording',  ...
                    'Tag', 'segment');

    hTrack = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Callback', @pipeline_Callback, ...
                    'Position', [0.89 0.66 0.09 0.06], ...
                    'String', 'Track Cells',  ...
                    'Tag', 'track');

    hPaths = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Callback', @pipeline_Callback, ...
                    'Position', [0.89 0.60 0.09 0.06], ...
                    'String', 'Filter Paths',  ...
                    'Tag', 'paths');

    hAutosave = uicontrol('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'Callback', @gui_Callback, ...
                         'Position', [0.9 0.54 0.1 0.05], ...
                         'String', 'Autosave',  ...
                         'Style', 'checkbox',  ...
                         'Value', 1, ...
                         'Tag', 'autosave');
    enabled = [enabled hAutosave];

    % The buttons which allows to change the colormap
    hColor = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @gui_Callback, ...
                       'Position', [0.89 0.4 0.08 0.04], ...
                       'Style', 'pushbutton',  ...
                       'FontSize', 10, ...
                       'String', 'Colormap',  ...
                       'Tag', 'color');
    enabled = [enabled hColor];

    % The buttons which allows to edit, load and save parameters
    hEdit = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @options_Callback, ...
                       'Position', [0.89 0.3 0.08 0.04], ...
                       'Style', 'pushbutton',  ...
                       'FontSize', 10, ...
                       'String', 'Edit parameters',  ...
                       'Tag', 'edit');
    enabled = [enabled hEdit];

    hLoad = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @options_Callback, ...
                       'Position', [0.89 0.2 0.08 0.04], ...
                       'Style', 'pushbutton',  ...
                       'FontSize', 10, ...
                       'String', 'Load parameters',  ...
                       'Tag', 'load');
    enabled = [enabled hLoad];

    hSave = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @options_Callback, ...
                       'Position', [0.89 0.15 0.08 0.04], ...
                       'Style', 'pushbutton',  ...
                       'FontSize', 10, ...
                       'String', 'Save parameters',  ...
                       'Tag', 'save');
    enabled = [enabled hSave];

    % We store all the useful handles into a structure to easily retrieve them,
    % along with some indexes
    handles = struct('uipanel', hPanel, ...
                     'slider1', hFrame1, ...
                     'slider2', hFrame2, ...
                     'text1', hIndex1, ...
                     'text2', hIndex2, ...
                     'list', hChannel, ...
                     'axes', [hAxes hAxesNext], ...
                     'experiment', hName, ...
                     'all_buttons', enabled, ...
                     'pipeline', [hProcess, hSegment, hTrack, hPaths], ...
                     'auto', hAutosave, ...
                     'save',[hSaveExp hExport], ...
                     'img', -1, ...
                     'data', -1, ...
                     'prev_frame', [-1 -1], ...
                     'frame', [1 1], ...
                     'display', [1 1], ...
                     'prev_channel', -1, ...
                     'current', 1);

    % Link both axes and activate the pan
    linkaxes(handles.axes);

    return;
  end
end
