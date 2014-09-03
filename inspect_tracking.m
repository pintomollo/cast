function [mytracking, opts, is_updated] = inspect_tracking(mytracking, opts)
% INSPECT_TRACKING displays a pop-up window for the user to manually inspect the
% segmentation that will be performed on the provided movie.
%
%   [MYTRACKING, OPTS] = INSPECT_TRACKING(MYTRACKING,OPTS) displays the window using
%   the data contained in MYTRACKING and the parameter values from OPTS. It updates
%   them accordingly to the user's choice. MYTRACKING should be a 'mytracking'
%   structure as created by inspect_recording.m
%
%   [...] = INSPECT_TRACKING() prompts the user to select a MYTRACKING containing
%   Matlab file before opening the GUI.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 17.06.2014

  % Argument checking, need to know if we ask for a mytracking file or not.
  if (nargin ~= 2 | isempty(mytracking) | isempty(opts))

    % Fancy output
    disp('[Select a MAT file]');

    % Prompting the user for the MAT file
    [fname, dirpath] = uigetfile({'*.mat'}, ['Load a MAT file']);
    fname = fullfile(dirpath, fname);

    % Load the matrix and check its content
    data = load(fname);

    % Not what we expected
    if (~isfield(data, 'mytracking') || ~isfield(data, 'opts'))
      disp(['Error: ' fname ' does not contain a valid mytracking structure']);

      return;

    % Extract the loaded data
    else
      mytracking = data.mytracking;
      opts = data.opts;
    end
  end

  % Store the original options
  orig_opts = opts;

  % Prepare some global variables
  channels = mytracking.channels;
  nchannels = length(channels);
  segmentations = mytracking.segmentations;

  % Make sure the expected structure is present
  if (length(segmentations) ~= nchannels)
    segmentations = get_struct('segmentation', [1, nchannels]);
  end

  % We will also need the detections, even if empty !
  for i=1:nchannels
    nframes = size_data(channels(i));
    if (length(segmentations(i).detections) < nframes)
      segmentations(i).detections = get_struct('detection', [1 nframes]);
    end
  end

  % Create the GUI using segmentations
  [hFig, handles] = create_figure();

  % Allocate the various images. This allows them to be "persistent" between
  % different calls to the callback functions.
  orig_img = [];
  img_next = [];
  spots = [];
  spots_next = [];
  paths = [];
  is_updated = true;

  % And handle the colormaps as well
  colors = get_struct('colors');
  color_index = 1;

  % Display the figure
  set(hFig,'Visible', 'on');
  % Update its content
  update_display;
  % And wait until the user is done
  uiwait(hFig);

  % Store the segmentations
  mytracking.channels = channels;
  % Store the segmentations
  mytracking.segmentations = segmentations;
  % And get the experiment name
  mytracking.experiment = get(handles.experiment, 'String');
  % And reset the other fields
  if (is_updated)
    mytracking.trackings = get_struct('tracking', 0);
  end

  % Delete the whole figure
  delete(hFig);
  drawnow;

  return;

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
    if (indx < 1)
      return;
    end

    % If we have changed channel, we need to update the display of the buttons
    if (indx ~= handles.prev_channel)

      % Get the colormap for the displayed channel
      color_index = channels(indx).color;

      % The name
      set(handles.uipanel,'Title', [channels(indx).type ' ' num2str(indx)]);

      % And setup the indexes correctly
      handles.prev_channel = indx;
      handles.prev_frame = -1;
    end

    if (recompute)
      % Because it takes long, display it and block the GUI
      set(hFig, 'Name', 'Tracking (Processing...)');

      % The slider
      set(handles.text, 'String', ['Frame #' num2str(nimg)]);

      set(handles.all_buttons, 'Enable', 'off');
      drawnow;
      refresh(hFig);

      % Here we recompute all the filtering of the frame
      noise = [];

      % Try to avoid reloading frames as much as possible
      if (handles.prev_frame == nimg-1)
        orig_img = img_next;
        img_next = double(load_data(channels(indx).fname, nimg+1));
      elseif (handles.prev_frame == nimg+1)
        img_next = orig_img;
        orig_img = double(load_data(channels(indx).fname, nimg));
      elseif (handles.prev_frame ~= nimg)
        orig_img = double(load_data(channels(indx).fname, nimg));
        img_next = double(load_data(channels(indx).fname, nimg+1));
      end

      spots = [segmentations(indx).detections(nimg).carth segmentations(indx).detections(nimg).properties];
      if (~isempty(img_next))
        spots_next = [segmentations(indx).detections(nimg+1).carth segmentations(indx).detections(nimg+1).properties];
      end

      spots = spots(all(~isnan(spots),2),:);
      spots_next = spots_next(all(~isnan(spots_next),2),:);

      links = track_spots({spots, spots_next}, {opts.spot_tracking.linking_function}, (opts.spot_tracking.spot_max_speed/opts.pixel_size)*opts.time_interval, opts.spot_tracking.bridging_max_gap, opts.spot_tracking.max_intensity_ratio, opts.spot_tracking.allow_branching_gap);

      paths = reconstruct_tracks({spots, spots_next}, links);

      % Update the index
      handles.prev_frame = nimg;
    end

    % Determine which image to display in the left panel
    switch handles.display(1)

      % The reconstructed image
      case 2
        spots1 = {spots};
        links1 = paths;

      % The difference between filtered and reconstructed
      case 3
        spots1 = {spots, spots_next};
        links1 = paths;

      % The filtered image
      otherwise
        spots1 = {[]};
        links1 = {[]};
    end

    % Determine which image to display in the right panel
    switch handles.display(2)

      % The reconstructed image
      case 2
        spots2 = {spots_next};
        links2 = paths;

      % The difference between filtered and reconstructed
      case 3
        spots2 = {spots_next, spots};
        links2 = paths;

      % The filtered image
      otherwise
        spots2 = {[]};
        links2 = {[]};
    end

    % Get the colors for the display
    spots_colors = [colors.spots{color_index}, colors.spots_next{color_index}];
    links_colors = colors.links{color_index};

    % If we have already created the axes and the images, we can simply change their
    % content (i.e. CData)
    if (numel(handles.img) > 1 & all(ishandle(handles.img)))
      set(handles.img(1),'CData', orig_img);
      set(handles.img(2),'CData', img_next);

      plot_spots(handles.data(1), spots1, spots_colors);
      plot_spots(handles.data(2), spots2, spots_colors([2 1]));

      plot_paths(handles.data(3), links1, links_colors);
      plot_paths(handles.data(4), links2, links_colors);
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

      % Now add the detected spots
      handles.data(1) = plot_spots(handles.axes(1), spots1, spots_colors);
      handles.data(2) = plot_spots(handles.axes(2), spots2, spots_colors([2 1]));

      % And their links
      handles.data(3) = plot_paths(handles.axes(1), links1, links_colors);
      handles.data(4) = plot_paths(handles.axes(2), links2, links_colors);

      % Drag and Zoom library from Evgeny Pr aka iroln
      dragzoom(handles.axes, 'on')
    end

    % And set the colormap
    colormap(hFig, colors.colormaps{color_index}());

    if (recompute)
      % Release the image
      set(hFig, 'Name', 'Tracking');
      set(handles.all_buttons, 'Enable', 'on');
    end

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
        [opts.spot_tracking, recompute] = edit_options(opts.spot_tracking);

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
    update_display(recompute);

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
      case {'detrend','denoise'}
        segmentations(indx).(type) = logical(get(hObject, 'Value'));

      % But filtering does not require recomputing
      case 'filter_spots'
        segmentations(indx).(type) = logical(get(hObject, 'Value'));
        recompute = false;

      % The slider varies the frame index
      case 'slider'
        handles.frame = round(get(hObject, 'Value'));

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

      % A different selection in one of the drop-down lists
      case 'type'
        segmentations(indx).(type) = get(hObject, 'Value');

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

  function cancel_CloseRequestFcn(hObject, eventdata)
  % This function stops the current processing after confirmation

    % Just double check that the user want to quit
    answer = questdlg('Do you really want to discard all your changes ?');
    ok = strcmp(answer,'Yes');

    % If everything is OK, release the GUI and quit
    if (ok)
      is_updated = false;
      opts = orig_opts;
      uiresume(hFig);
    end

    return
  end

  function channel_CloseRequestFcn(hObject, eventdata)
  % This function converts the various indexes back into strings to prepare
  % the segmentations structure for its standard form.

    uiresume(hFig);

    return
  end

  function [hFig, handles] = create_figure
  % This function actually creates the GUI, placing all the elements
  % and linking the calbacks.

    % The number of channels provided
    nchannels = length(channels);

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
    nframes = size_data(channels(1).fname);

    % And the experiment name
    exp_name = mytracking.experiment;

    % Create my own grayscale map for the image display
    mygray = [0:255]' / 255;
    mygray = [mygray mygray mygray];

    % We build a list of all buttons to easily block and release them
    enabled = [];

    % The main figure, cannot be rescaled, closed nor deleted
    hFig = figure('PaperUnits', 'centimeters',  ...
                  'CloseRequestFcn', @gui_Callback, ...
                  'Color',  [0.7 0.7 0.7], ...
                  'Colormap', mygray, ...
                  'MenuBar', 'none',  ...
                  'Name', 'Tracking',  ...
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
                         'String', liststring, ...
                         'Style', 'listbox',  ...
                         'Value', 1, ...
                         'Tag', 'channels');
    enabled = [enabled hChannel];

    % The OK button
    hOK = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @channel_CloseRequestFcn, ...
                    'Position', [0.70 0.02 0.18 0.05], ...
                    'String', 'OK',  ...
                    'Tag', 'pushbutton11');
    enabled = [enabled hOK];

    % The Cancel button
    hCancel = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @cancel_CloseRequestFcn, ...
                    'Position', [0.90 0.02 0.08 0.05], ...
                    'String', 'Cancel',  ...
                    'Tag', 'pushbutton12');
    enabled = [enabled hCancel];

    % The experiment name and its labels
    hText = uicontrol('Parent', hFig, ...
                      'Units', 'normalized',  ...
                      'Position', [0.2 0.93 0.09 0.025], ...
                      'String', 'Experiment name:',  ...
                      'BackgroundColor', get(hFig, 'Color'), ...
                      'FontSize', 12, ...
                      'Style', 'text',  ...
                      'Tag', 'text1');

    hName = uicontrol('Parent', hFig, ...
                      'Units', 'normalized',  ...
                      'Position', [0.3 0.93 0.5 0.05], ...
                      'String', exp_name,  ...
                      'FontSize', 12, ...
                      'Style', 'edit',  ...
                      'Tag', 'experiment');
    enabled = [enabled hName];

    % The slider and its label
    hIndex = uicontrol('Parent', hFig, ...
                      'Units', 'normalized',  ...
                      'Position', [0.2 0.03 0.09 0.025], ...
                      'String', 'Frame #1',  ...
                      'BackgroundColor', get(hFig, 'Color'), ...
                      'FontSize', 12, ...
                      'Style', 'text',  ...
                      'Tag', 'text2');

    hFrame = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @gui_Callback, ...
                    'Position', [0.3 0.03 0.35 0.025], ...
                    'Value', 1, ...
                    'SliderStep', [1 10]/nframes, ...
                    'Max', max(nframes, 1.1), ...
                    'Min', 1, ...
                    'Style', 'slider', ...
                    'Tag', 'slider');
    enabled = [enabled hFrame];

    %%%%%%% Now the main panel

    % The panel itsel
    hPanel = uipanel('Parent', hFig, ...
                     'Title', [channels(1).type '1'],  ...
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
                         'Position', [0.1 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'No detection', ...
                         'Tag', 'radio11');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.4 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Current frame', ...
                         'Tag', 'radio12');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.7 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Both frames', ...
                         'Tag', 'radio13');
    enabled = [enabled hControl];

    % The second group
    hRadio = uibuttongroup('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'SelectionChangeFcn', @gui_Callback, ...
                         'Position', [0.44 0.05 0.43 0.05], ...
                         'tag', 'radio');

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.1 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'No detection', ...
                         'Tag', 'radio21');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.4 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Next frame', ...
                         'Tag', 'radio22');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.7 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Both frames', ...
                         'Tag', 'radio23');
    enabled = [enabled hControl];

    % The buttons which allows to change the colormap
    hColor = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @gui_Callback, ...
                       'Position', [0.89 0.77 0.08 0.04], ...
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
                     'slider', hFrame, ...
                     'text', hIndex, ...
                     'list', hChannel, ...
                     'axes', [hAxes hAxesNext], ...
                     'experiment', hName, ...
                     'all_buttons', enabled, ...
                     'img', -1, ...
                     'data', -1, ...
                     'prev_frame', -1, ...
                     'frame', 1, ...
                     'display', [1 1], ...
                     'prev_channel', -1, ...
                     'current', 1);

    % Link both axes and activate the pan
    linkaxes(handles.axes);

    return;
  end
end
