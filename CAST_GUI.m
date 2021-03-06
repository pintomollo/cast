function [myrecording, opts] = CAST_GUI(myrecording, opts)
% CAST_GUI displays the main window of this interactive segmentation and
% tracking platform in time-lapse recordings.
%
%   CAST_GUI() displays an empty GUI for the user to load a recording interactively.
%
%   [MYRECORDING, OPTS] = CAST_GUI() returns the results of the analysis in MYRECORDING
%   and the corresponding options in OPTS. MYRECORDING and OPTS will be structured as defined
%   get_struct('myrecording') and get_struct('options') respectively.
%
%   [MYRECORDING, OPTS] = CAST_GUI(MYRECORDING, OPTS) displays the window using
%   the data contained in MYRECORDING and the parameter values from OPTS. It updates
%   them accordingly to the user's choice.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 02.07.2014

  % Argument checking, need to know if we create new structures or not
  if (nargin ~= 2 | isempty(myrecording) | isempty(opts))
    myrecording = get_struct('myrecording');
    opts = get_struct('options');
  else
    % We utilize this function to improve compatibility between versions of this
    % platform, fusing option structures if need be.
    opts = update_structure(opts, 'options');
  end

  % Prepare some global variables
  channels = myrecording.channels;
  nchannels = length(channels);
  nframes = 1;
  segmentations = myrecording.segmentations;
  trackings = myrecording.trackings;
  has_segmentation = false;
  has_tracking = false;
  has_filtered = false;
  autosave = true;
  colors = get_struct('colors');
  color_index = 1;

  % Dragzoom help message
  imghelp = regexp(help('dragzoom'), ...
             '([ ]+Normal mode:.*\S)\s+Mouse actions in 3D','tokens');
  imghelp = ['DRAGZOOM interactions (help dragzoom):\n\n', imghelp{1}{1}];

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
  all_filtered = {[]};
  paths = {[]};
  all_colors = [];
  all_colors_filtered = [];
  is_updated = true;
  paths = [];

  % Display the figure
  set(hFig,'Visible', 'on');
  % Update its content
  update_display;
  % And wait until the user is done
  uiwait(hFig);

  if (is_updated)
    % Store the segmentations
    myrecording.segmentations = segmentations;
    % And get the experiment name
    if (nchannels > 0)
      myrecording.experiment = get(handles.experiment, 'String');
    end
  end

  % Delete the whole figure
  delete(hFig);
  drawnow;

  % Prevent any output
  if (nargout == 0)
    clearvars
  end

  return;

  function setup_environment()
  % This function steups all the variables and GUI elements required for it to work

    % Some default global variables
    channels = myrecording.channels;
    nchannels = length(channels);
    segmentations = myrecording.segmentations;
    trackings = myrecording.trackings;

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
    exp_name = myrecording.experiment;
    if (isempty(exp_name))
      exp_name = 'Load a recording here -->';
    end

    % Set the parameters for the sliders
    if isfinite(nframes)
      slider_step = [1 10]/nframes;
      slider_max = max(nframes, 1.1);
      slider_min = 1;
    else
      slider_step = [1 1];
      slider_max = 1.1;
      slider_min = 1;
    end

    % The title of the current panel
    if (nchannels > 0)
      panel_title = [channels(1).type '1'];
    else
      panel_title = '';
    end

    % Update the lists and experiment name
    set(handles.list, 'String', liststring);
    set(handles.experiment, 'String', exp_name);

    % Apply the values to the sliders
    set(handles.slider1, 'SliderStep', slider_step, 'Max', slider_max, 'Min', slider_min, 'Value', 1);
    set(handles.slider2, 'SliderStep', slider_step, 'Max', slider_max, 'Min', slider_min, 'Value', 1);
    set(handles.text1, 'String', 'Frame #1');
    set(handles.text2, 'String', 'Frame #1');

    % And the title
    set(handles.uipanel, 'Title', panel_title);

    % Initialize the ounters and "pointers" used by the GUI
    handles.prev_frame = [-1 -1];
    handles.frame = [1 1];
    handles.prev_channel = -1;
    handles.current = 1;

    % Now check which steps have already been done in this recording
    has_segmentation = false;
    has_tracking = false;
    has_filtered = false;

    % Well, without data, nothing is possible
    if (nchannels == 0)
      set(handles.save, 'Enable', 'off');
      set(handles.pipeline(2:end), 'Enable', 'off')
      set(handles.pipeline(1), 'String', 'Load Recording')
    else
      % Now that's a start !
      set(handles.save, 'Enable', 'on');
      set(handles.pipeline, 'Enable', 'on');
      set(handles.pipeline(1), 'String', 'Process Recording')

      % But without detections, nothing goes further
      if (isempty(segmentations))
        set(handles.pipeline(3:end), 'Enable', 'off')
      else

        % Now do we have the trackings as well ?
        has_segmentation = true;
        if (~isempty(trackings) && (length(trackings(1).detections)==nframes))
          has_tracking = true;

          % Make sure we even have filtered them...
          if (isfield(trackings(1), 'filtered') && (length(trackings(1).filtered)==nframes))
            for i=1:nframes
              has_filtered = (~isempty(trackings(1).filtered(i).cluster));
              if has_filtered
                break;
              end
            end
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

        delete(get(handles.data(1), 'Children'));
        delete(get(handles.data(2), 'Children'));
        delete(get(handles.data(3), 'Children'));
        delete(get(handles.data(4), 'Children'));

        set(handles.scale, 'XData', [], 'YData', []);
      end

      return;
    end

    % If we have changed channel, we need to update the display of the buttons
    if (indx ~= handles.prev_channel && indx <= nchannels)
      % Because it takes long, display it and block the GUI
      color_index = channels(indx).color(1);
      set(hFig, 'Name', 'CAST (Processing...)');
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
      all_paths = [];

      % Check what is available in the structure
      has_segmentation = false;
      has_tracking = false;
      has_filtered = false;

      if (~isempty(segmentations))
        has_segmentation = true;
        if (~isempty(trackings) && (length(trackings(indx).detections)==nframes))
          has_tracking = true;

          if (isfield(trackings(indx), 'filtered') && (length(trackings(indx).filtered)==nframes))
            for i=1:nframes
              has_filtered = (~isempty(trackings(indx).filtered(i).cluster));
              if has_filtered
                break;
              end
            end
          end
        end
      end

      % Reconstruct the available tracks
      if ~has_tracking
        all_paths = {[]};
      else
        all_paths = reconstruct_tracks(trackings(indx).detections, true);
      end
      if ~has_filtered
        all_filtered = {[]};
      else
        all_filtered = reconstruct_tracks(trackings(indx).filtered, true);
      end

      set(hFig, 'Name', 'CAST');
      set(all_all, {'Enable'}, curr_status);
    end

    % And get the corresponding colormaps
    all_colors = colorize_graph(all_paths, colors.paths{color_index}(length(all_paths)));
    all_colors_filtered = colorize_graph(all_filtered, colors.paths{color_index}(length(all_filtered)));

    % The slider
    set(handles.text1, 'String', ['Frame #' num2str(nimg(1))]);
    set(handles.text2, 'String', ['Frame #' num2str(nimg(2))]);

    if (recompute)
      % Because it takes long, display it and block the GUI
      set(hFig, 'Name', 'CAST (Processing...)');
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

    % Determine which data to display in the left panel
    switch handles.display(1)

      % The segmented image
      case 2
        if has_segmentation
          spots1 = [segmentations(indx).detections(nimg(1)).carth segmentations(indx).detections(nimg(1)).properties];
        else
          spots1 = [];
        end
        links1 = {[]};
        colors1 = [];
        divisions_colors1 = colors.spots{color_index};

      % The tracked spots
      case 3

        if has_tracking
          spots = cellfun(@(x)(x(x(:,end-1)==nimg(1),:)), all_paths, 'UniformOutput', false);
          spots = cat(1,spots{:});
          divs = spots(:,1);
          spots1 = {spots(divs<0,2:end), spots(divs==0,2:end), spots(divs>0,2:end)};
          links1 = cellfun(@(x)(x(abs(x(:,end-1)-nimg(1)) < 2,:)), all_paths, 'UniformOutput', false);
          links1 = links1(~cellfun('isempty', links1));
        else
          spots1 = {[]};
          links1 = {[]};
        end
        colors1 = colorize_graph(links1, colors.paths{color_index}(length(links1)));
        divisions_colors1 = colors.status{color_index};

      % The full paths
      case 4
        if has_filtered
          spots = cellfun(@(x)(x(x(:,end-1)==nimg(1),:)), all_filtered, 'UniformOutput', false);
          spots = cat(1,spots{:});
          divs = spots(:,1);
          spots1 = {spots(divs<0,2:end), spots(divs==0,2:end), spots(divs>0,2:end)};
        else
          spots1 = {[]};
        end
        links1 = all_filtered;
        colors1 = all_colors_filtered;
        divisions_colors1 = colors.status{color_index};

      % The image only
      otherwise
        spots1 = {[]};
        links1 = {[]};
        colors1 = 'k';
        divisions_colors1 = 'k';
    end

    % Determine which image to display in the right panel
    switch handles.display(2)

      % The segmented image
      case 2
        if has_segmentation
          spots2 = [segmentations(indx).detections(nimg(2)).carth segmentations(indx).detections(nimg(2)).properties];
        else
          spots2 = {[]};
        end
        links2 = {[]};
        colors2 = [];
        divisions_colors2 = colors.spots_next{color_index};

      % The tracked data
      case 3
        if has_tracking
          spots_next = cellfun(@(x)(x(x(:,end-1)==nimg(2),:)), all_paths, 'UniformOutput', false);
          spots_next = cat(1,spots_next{:});
          divs = spots_next(:,1);
          spots2 = {spots_next(divs<0,2:end), spots_next(divs==0,2:end), spots_next(divs>0,2:end)};
          links2 = cellfun(@(x)(x(abs(x(:,end-1)-nimg(2)) < 2,:)), all_paths, 'UniformOutput', false);
          links2 = links2(~cellfun('isempty', links2));
        else
          spots2 = {[]};
          links2 = {[]};
        end
        colors2 = colorize_graph(links2, colors.paths{color_index}(length(links2)));
        divisions_colors2 = colors.status{color_index};

      % The full paths
      case 4
        if has_filtered
          spots_next = cellfun(@(x)(x(x(:,end-1)==nimg(2),:)), all_filtered, 'UniformOutput', false);
          spots_next = cat(1,spots_next{:});
          divs = spots_next(:,1);
          spots2 = {spots_next(divs<0,2:end), spots_next(divs==0,2:end), spots_next(divs>0,2:end)};
        else
          spots2 = {[]};
        end
        links2 = all_filtered;
        colors2 = all_colors;
        divisions_colors2 = colors.status{color_index};

      % The image alone
      otherwise
        spots2 = {[]};
        links2 = {[]};
        colors2 = 'k';
        divisions_colors2 = 'k';
    end

    % Get the type of segmentation used, if one is available
    if (has_segmentation)
      segment_type = segmentations(indx).type;
    else
      segment_type = 'unknown';
    end

    % If we have already created the axes and the images, we can simply change their
    % content (i.e. CData, XData, ...)
    [size_y, size_x] = size(orig_img);
    if (numel(handles.img) > 1 & all(ishandle(handles.img)))
      set(handles.img(1),'CData', orig_img);
      set(handles.img(2),'CData', img_next);

      plot_paths(handles.data(3), links1, colors1);
      plot_paths(handles.data(4), links2, colors2);

      perform_step('plotting', segment_type, handles.data(1), spots1, divisions_colors1, iscell(spots1));
      perform_step('plotting', segment_type, handles.data(2), spots2, divisions_colors2, iscell(spots2));

      set(handles.scale, 'XData', size_x*[0.05 0.05]+[0 10/opts.pixel_size], 'YData', size_y*[0.95 0.95]);
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
      handles.data(1) = perform_step('plotting', segment_type, handles.axes(1), spots1, divisions_colors1, iscell(spots1));
      handles.data(2) = perform_step('plotting', segment_type, handles.axes(2), spots2, divisions_colors2, iscell(spots2));

      % And the necessary scale bar
      handles.scale = line('XData', size_x*[0.05 0.05]+[0 10/opts.pixel_size], 'YData', size_y*[0.95 0.95], 'Parent', handles.axes(1), 'Color', 'w', 'LineWidth', 4);

      % Drag and Zoom library from Evgeny Pr aka iroln
      dragzoom(handles.axes, 'on')
    end
    colormap(hFig, colors.colormaps{color_index}());

    if (recompute)
      % Release the image
      set(hFig, 'Name', 'CAST');
      set(handles.all_buttons, {'Enable'}, curr_status);
    end

    return
  end

  function experiment_Callback(hObject, eventdata)
  % This function is responsible for handling the content of the
  % structure which contains the parameters of the filtering algorithms.

    % Block the GUI
    all_all = [handles.all_buttons, handles.save, handles.pipeline];
    curr_status = get(all_all, 'Enable');
    set(all_all, 'Enable', 'off');
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
            uisave({'myrecording','opts'}, [myrecording.experiment '.mat'])
          end
        end

        % Reset the current display
        if (all(ishandle(handles.img)))
          delete(handles.img);
          delete(handles.data);
          delete(handles.scale);
          dragzoom(handles.axes, 'off')
          set(hFig, 'UserData', '');
        end

        % Fancy output
        disp('[Select a MAT file]');

        % Prompting the user for the MAT file
        [fname, dirpath] = uigetfile({'*.mat'}, ['Load a MAT file']);

        % Not cancelled
        if (ischar(fname))

          fname = fullfile(dirpath, fname);

          % Load the matrix and check its content
          data = load(fname);

          % Not what we expected
          if (~isfield(data, 'myrecording') || ~isfield(data, 'opts'))
            disp(['Error: ' fname ' does not contain a valid myrecording structure']);

          % Extract the loaded data
          else
            myrecording = data.myrecording;
            opts = update_structure(data.opts, 'options');
          end
        end

      % Call the saving function
      case 'save'
        uisave({'myrecording','opts'}, [myrecording.experiment '.mat'])
        recompute = false;

      % Export the results
      case 'export'
        props = get_struct('exporting');
        props.file_name = myrecording.experiment;
        myrecording.channels = channels;

        [props, do_export] = edit_options(props);
        if (do_export)
          if (props.export_data)
            export_tracking(myrecording, props, opts);
          end
          if (props.export_movie)
            export_movie(myrecording, props, opts);
          end
        end
        recompute = false;
    end

    % Release the GUI and recompute the filters
    set(all_all, {'Enable'}, curr_status);
    if (recompute)
      setup_environment()
      update_display(recompute);
    end

    return
  end

  function options_Callback(hObject, eventdata)
  % This function is responsible for handling the content of the
  % structure which contains the parameters of the filtering algorithms.

    % Block the GUI
    all_all = [handles.all_buttons, handles.save, handles.pipeline];
    curr_status = get(all_all, 'Enable');
    set(all_all, 'Enable', 'off');
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
        tmp_list = opts.config_files;
        opts.config_files = {};
        opts = load_parameters(opts);
        opts.config_files = [tmp_list(:); opts.config_files(:)];

      % Call the saving function
      case 'save'
        save_parameters(opts);
        recompute = false;

      % Clean the TmpData folder
      case 'clean'
        clean_tmp_files();

      % Save a snapshot
      case 'snapshot'

        % Fancy output
        disp('[Select a SVG filename]');

        % Prompting the user for the filename
        [fname, dirpath] = uiputfile({'*.svg', 'SVG vectorized image'}, ['Select a filename for your snapshot'], 'export/snapshot.svg');

        % Not cancelled
        if (ischar(fname))

          % This might take a while
          curr_name = get(hFig, 'Name');
          set(hFig, 'Name', [curr_name ' (Saving snapshot...)']);

          % Get the full name and save the snapshot !
          fname = fullfile(dirpath, fname);
          plot2svg(fname, hFig);

          % And release !
          set(hFig, 'Name', curr_name);
        end

        recompute = false;
    end

    % Release the GUI and recompute the filters
    set(all_all, {'Enable'}, curr_status);
    if (recompute)
      setup_environment()
      update_display(recompute);
    end

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

      % Create a new, empty experiment
      case 'new'
        myrecording = get_struct('myrecording');
        opts = get_struct('options');

      % Call the data processing GUI and process the channels accordingly
      case 'process'
        set(hFig, 'Visible', 'off')
        [myrecording, opts, reload] = inspect_recording(myrecording, opts);
        if (reload)
          [myrecording, opts] = preprocess_movie(myrecording, opts);
          if (autosave)
            save([myrecording.experiment '.mat'], 'myrecording', 'opts');
          end
          [opts, recompute] = edit_options(opts);
        end
        set(hFig, 'Visible', 'on')

      % Call the segmenting GUI, and segment accordingly
      case 'segment'
        set(hFig, 'Visible', 'off')
        [myrecording, opts, reload] = inspect_segmentation(myrecording, opts);
        if (reload)
          [myrecording, opts] = segment_movie(myrecording, opts);
          if (autosave)
            save([myrecording.experiment '.mat'], 'myrecording', 'opts');
          end
        end
        set(hFig, 'Visible', 'on')

      % Call the cell tracking GUI, and track accordingly
      case 'track'
        set(hFig, 'Visible', 'off')
        [myrecording, opts, reload] = inspect_tracking(myrecording, opts);
        if (reload)
          [myrecording, opts] = track_spots(myrecording, opts);
          if (autosave)
            save([myrecording.experiment '.mat'], 'myrecording', 'opts');
          end
        end
        set(hFig, 'Visible', 'on')

      % Call the path filtering GUI, and filter accordingly
      case 'paths'
        set(hFig, 'Visible', 'off')
        [myrecording, opts, reload] = inspect_paths(myrecording, opts);
        if (reload)
          [myrecording, opts] = filter_paths(myrecording, opts);
          if (autosave)
            save([myrecording.experiment '.mat'], 'myrecording', 'opts');
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

    myrecording.channels = channels;
    if (nchannels > 0)
      answer = questdlg('Save the current project ?', 'Save ?');
      if (strncmp(answer, 'Yes', 3))
        uisave({'myrecording','opts'}, [myrecording.experiment '.mat'])
      end
    end

    if (nchannels == 0 || ~strncmp(answer, 'Cancel', 6))
      uiresume(hFig);
    end

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
                  'Name', 'CAST',  ...
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

    hFrame1 = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @gui_Callback, ...
                    'Position', [0.19 0.03 0.28 0.025], ...
                    'Value', 1, ...
                    'SliderStep', [1 10]/nframes, ...
                    'Max', max(nframes, 1.1), ...
                    'Min', 1, ...
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
                    'SliderStep', [1 10]/nframes, ...
                    'Max', max(nframes, 1.1), ...
                    'Min', 1, ...
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

    % The Snapshot button
    hSnapshot = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @options_Callback, ...
                    'Position', [0.01 0.93 0.05 0.05], ...
                    'String', 'Snapshot',  ...
                    'Tag', 'snapshot');
    enabled = [enabled hSnapshot];

    % The Cleaning button
    hClean = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @options_Callback, ...
                    'Position', [0.01 0.03 0.075 0.035], ...
                    'String', 'Clean TmpData',  ...
                    'Tag', 'clean');
    enabled = [enabled hClean];

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
                     'scale', -1, ...
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
