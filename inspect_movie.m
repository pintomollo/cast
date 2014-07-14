function [mytracking, opts] = inspect_movie(fname)
% INSPECT_MOVIE displays a pop-up window for the user to manually identify the
% type of data contained in the different channels of a movie recording.
%
%   [MYTRACKING] = INSPECT_MOVIE(CHANNELS) displays the window using the data
%   contained in CHANNELS, updates it accordingly to the user's choice and returns
%   the adequate structure for later analysis MYTRACKING. CHANNELS can either
%   be a string, a cell list of strings or a 'channel' structure (see get_struct.m).
%
%   [...] = INSPECT_MOVIE() prompts the user to select a recording and converts
%   it before opening the GUI.
%
%   [MYTRACKING, OPTS] = INSPECT_MOVIE(...) returns in addition the parameters
%   required to filter the various channels as chosen by the user.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 14.05.2014

  % Argument checking, need to know if we ask for a recording or not.
  if (nargin == 0 | isempty(fname))
    fname = convert_movie();
  end

  % The structure containing the parameters for the different filters available to
  % the user.
  opts = get_struct('options');

  % Create the channels structure if it was not provided.
  if (isstruct(fname))
    channels = fname;
  else
    % Put everything in a cell list
    if (ischar(fname))
      fname = {fname};
    end

    % Parse the list and copy its content into channels
    nchannels = length(fname);
    channels = get_struct('channel', [nchannels 1]);
    for i=1:nchannels
      channels(i).fname = fname{i};
    end
  end

  % Create the GUI using channels
  [hFig, handles] = create_figure();

  % Allocate the various images. This allows them to be "persistent" between
  % different calls to the callback functions.
  img = [];
  orig_img = [];
  img_next = [];

  % Display the figure
  set(hFig,'Visible', 'on');
  % Update its content
  update_display;
  % And wait until the user is done
  uiwait(hFig);

  % Now that the data are correct, create the whole structure
  mytracking = get_struct('mytracking');
  % Copy the channels
  mytracking.channels = channels;
  % And get the experiment name
  mytracking.experiment = get(handles.experiment, 'String');

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
      % The name
      set(handles.uipanel,'Title', ['Channel ' num2str(indx)]);

      % The filters
      set(handles.detrend,'Value', channels(indx).detrend);
      set(handles.hot_pixels,'Value', channels(indx).hot_pixels);
      set(handles.normalize,'Value', channels(indx).normalize);
      set(handles.cosmics,'Value', channels(indx).cosmics);

      % Here we use a trick to have a colored button using HTML formatting
      rgb_color = round(channels(indx).color * 255);
      set(handles.channel_color, 'String', ['<HTML><BODY bgcolor = "rgb(' num2str(rgb_color(1)) ', ' num2str(rgb_color(2)) ', ' num2str(rgb_color(3)) ')">green background</BODY></HTML>'])
      set(handles.channel_color, 'ForegroundColor', channels(indx).color);

      % The type and compression
      set(handles.channel_type, 'Value',  channels(indx).type);
      set(handles.compress, 'Value',  channels(indx).compression);

      % And setup the indexes correctly
      handles.prev_channel = indx;
      handles.prev_frame = -1;
    end

    % Here we recompute all the filtering of the frame
    if (recompute)
      % Because it takes long, display it and block the GUI
      set(hFig, 'Name', 'Channel Identification (Filtering...)');
      set(handles.text, 'String', ['Frame #' num2str(nimg)]);
      set(handles.all_buttons, 'Enable', 'off');
      drawnow;
      refresh(hFig);

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
      % Update the index
      handles.prev_frame = nimg;

      % Copy to the working variable
      img = orig_img;

      % Detrend the image ?
      if (channels(indx).detrend)
        img = imdetrend(img, opts.filtering.detrend_meshpoints);
      end

      % Remove cosmic rays ?
      if (channels(indx).cosmics)
        img = imcosmics(img, opts.filtering.cosmic_rays_window_size, opts.filtering.cosmic_rays_threshold);
      end

      % Remove hot pixels ?
      if (channels(indx).hot_pixels)
        img = imhotpixels(img, opts.filtering.hot_pixels_threshold);
      end

      % Normalize the image ?
      if (channels(indx).normalize)
        img = imnorm(img);
      end
    end

    % Determine which image to display in the left panel
    switch handles.display(1)

      % The raw image
      case 2
        img1 = orig_img;

      % The difference between filtered and raw
      case 3
        if (channels(indx).normalize)
          img1 = (imnorm(orig_img) - img);
        else
          img1 = orig_img - img;
        end

      % The filtered image
      otherwise
        img1 = img;
    end

    % Determine which image to display in the right panel
    switch handles.display(2)

      % Next frame
      case 2
        img2 = img_next;

      % Difference between current and next frame
      case 3
        img2 = (orig_img - img_next);

      % Raw image
      otherwise
        img2 = orig_img;
    end

    % If we have already created the axes and the images, we can simply change their
    % content (i.e. CData)
    if (numel(handles.img) > 1 & all(ishandle(handles.img)))
      set(handles.img(1),'CData', img1);
      set(handles.img(2),'CData', img2);
    else

      % Otherwise, we create the two images in their respective axes
      handles.img = image(img1,'Parent', handles.axes(1),'CDataMapping', 'scaled');
      handles.img(2) = image(img2,'Parent', handles.axes(2),'CDataMapping', 'scaled');

      % Hide the axes and prevent a distortion of the image due to stretching
      set(handles.axes,'Visible', 'off',  ...
                 'DataAspectRatio',  [1 1 1]);

      % Drag and Zoom library from Evgeny Pr aka iroln
      dragzoom(handles.axes, 'on')
    end

    % Release the image if need be
    if (recompute)
      set(hFig, 'Name', 'Channel Identification');
      set(handles.all_buttons, 'Enable', 'on');
    end

    return
  end

  function remove_channel_Callback(hObject, eventdata)
  % This function removes ones channel from the list

    % Get the current index for later
    indx = handles.current;

    % And ask for confirmation
    answer = questdlg(['Are you sure you want to remove channel ' num2str(indx) ' ?' ...
                '(No data will be deleted from the disk)'], 'Removing a channel ?');
    ok = strcmp(answer, 'Yes');

    % If it's ok, let's go
    if (ok)

      % Remove the current index and select the first one
      channels(indx) = [];
      handles.current = 1;

      % If it was the last one, we need to handle this
      if (length(channels) == 0)

        % Set up the indexes
        handles.current = 0;
        handles.prev_channel = -1;

        % As this is long, block the GUI
        set(handles.all_buttons, 'Enable', 'off');
        set(handles.img, 'CData', []);
        set(handles.list, 'String', '');

        % And call the movie conversion function
        new_channel = convert_movie();

        if (~isempty(new_channel))
          % Get the number of frames in each of them
          nframes = size_data(new_channel);

          set(handles.slider, 'Max', nframes-1, 'Value', 1);

          % We provide basic default values for all fields
          channels = get_struct('channel');
          channels.fname = new_channel;
          channels.type = 1;
          channels.compression = 1;

          % We update the list of available channels
          set(handles.list, 'String', 'Channel 1', 'Value', 1);
        end

      % Otherwise, delete the last traces of the deleted channel
      else
        handles.prev_channel = -1;
        tmp_list = get(handles.list, 'String');
        last_indx = findstr(tmp_list, '|');
        set(handles.list, 'String', tmp_list(1:last_indx(end)-1), 'Value', 1);
      end

      % Release the GUI and update
      set(handles.all_buttons, 'Enable', 'on');
      update_display(true);
    end

    return;
  end

  function add_channel_Callback(hObject, eventdata)
  % This function adds a new channel to the current recording

    nchannels = length(channels);

    % As this is long, block the GUI
    set(handles.all_buttons, 'Enable', 'off');

    % And call the movie conversion function
    new_channel = convert_movie();

    if (~isempty(new_channel))
      % Get the number of frames in each of them
      nframes = size_data(new_channel);
      curr_nframes = get(handles.slider, 'Max')+1;

      % If they are similar, we can add it to the current structure
      if (nchannels == 0 || nframes == curr_nframes)

        % We provide basic default values for all fields
        channels(end+1) = get_struct('channel');
        channels(end).fname = new_channel;
        channels(end).type = 1;
        channels(end).compression = 1;

        % We update the list of available channels
        tmp_list = get(handles.list, 'String');
        if (nchannels == 0)
          liststring = ['Channel ' num2str(length(channels))];
        else
          liststring = [tmp_list '|Channel ' num2str(length(channels))];
        end
        set(handles.list, 'String', liststring);

      % Otherwise, there is a problem !
      else
        errordlg(['Error: the selected channel does not have the same number of ' ...
                ' frames (' num2str(nframes) ') than the currently loaded ones (' ...
                num2str(curr_nframes) '), ignoring it.'],'Error: Adding a channel','modal');
      end
    end

    % Release the GUI
    set(handles.all_buttons, 'Enable', 'on');

    % If we just add a new first channel, we need to set it up properly and update
    if (nchannels == 0 && length(channels) > 0)
      handles.current = 1;
      set(handles.list, 'Value', 1);
      update_display(true);
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

    % Handle all three buttons differently
    switch type

      % Call the editing function
      case 'edit'
        opts.filtering = edit_options(opts.filtering);

      % Call the loading function
      case 'load'
        opts = load_parameters(opts);

      % Call the saving function
      case 'save'
        save_parameters(opts);
    end

    % Release the GUI and recompute the filters
    set(handles.all_buttons, 'Enable', 'on');
    update_display(true);

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
      case {'detrend', 'cosmics', 'hot_pixels', 'normalize'}
        channels(indx).(type) = logical(get(hObject, 'Value'));

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
      case {'type', 'compression'}
        channels(indx).(type) = get(hObject, 'Value');
        recompute = false;

      % The interactive color selection palette, followed by the HTML color trick
      case 'color'
        channels(indx).color = uisetcolor(channels(indx).color);
        rgb_color = round(channels(indx).color * 255);

        set(handles.channel_color, 'ForegroundColor',  channels(indx).color, ...
                                   'String', ['<HTML><BODY bgcolor = "rgb(' num2str(rgb_color(1)) ', ' num2str(rgb_color(2)) ', ' num2str(rgb_color(3)) ')">green background</BODY></HTML>']);
        recompute = false;

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
  % the channels structure for its standard form.

    % Create a copy of channels in case we need to cancel
    tmp_channels = channels;

    % We need ot loop over the channels
    nchannels = length(channels);

    % Get the available types of channels and compressions
    contents = get(handles.channel_type,'String');
    ntypes = length(contents);
    compressions = get(handles.compress,'String');

    % We want to check if some channels have identical features
    detrend = logical(zeros(nchannels,1));
    types = logical(zeros(nchannels,ntypes));
    colors = zeros(nchannels,3);

    % Convert the indexes into strings and build a summary of the filters
    for i=1:nchannels
      detrend(i) = channels(i).detrend;
      types(i,channels(i).type) = true;
      colors(i,:) = channels(i).color;
      tmp_channels(i).type = contents{channels(i).type};
      tmp_channels(i).compression = compressions{channels(i).compression};
    end

    % Some checks to make sure the user is aware of some potential issues
    ok = true;
    if (ok & any(detrend, 1))

      % This is a highly non-linear filtering which prevents proper
      % signal comparison between recordings
      answer = questdlg({'Some channels will be detrended, continue ?','', ...
                         '(This is a quite slow and non-linear process..)'});
      ok = strcmp(answer,'Yes');
    end
    if (ok & size(unique(colors,'rows'),1)~=nchannels)

      % Just in case, for later display
      answer = questdlg('Multiple channels have the same color, continue ?');
      ok = strcmp(answer,'Yes');
    end

    % If everything is OK, release the GUI and quit
    if (ok)
      channels = tmp_channels;
      uiresume(hFig);
    end

    return
  end

  function [hFig, handles] = create_figure
  % This function actually creates the GUI, placing all the elements
  % and linking the calbacks.

    % The number of channels provided
    nchannels = length(channels);

    % Initialize the possible types and compressions
    typestring = {'luminescence';'brightfield'; 'dic'; 'fluorescence'};
    typecompress = {'none', 'lzw', 'deflate', 'jpeg'};

    % Initialize the structure used for the interface
    liststring = '';
    for i = 1:nchannels

      % Build the displayed list
      liststring = [liststring 'Channel ' num2str(i)];
      if (i < nchannels)
        liststring = [liststring '|'];
      end

      % Set the currently selected type of data
      for j = 1:length(typestring)
        if (strcmp(channels(i).type, typestring{j}))
          channels(i).type = j;

          break;
        end
      end

      % If the type did not exist, use the first one
      if (ischar(channels(i).type))
        channels(i).type = 1
      end

      % Set the compression type
      for j = 1:length(typecompress)
        if (strcmpi(channels(i).compression, typecompress{j}))
          channels(i).compression = j;

          break;
        end
      end

      % If none was found, choose the first one
      if (ischar(channels(i).compression))
        channels(i).compress = 1;
      end
    end

    % Get the number of frames
    nframes = size_data(channels(1).fname);

    % Create a name for the experiment
    exp_name = channels(1).fname;
    [junk, exp_name, junk] = fileparts(exp_name);
    [junk, exp_name, junk] = fileparts(exp_name);
    exp_name = regexprep(exp_name, ' ', '');

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
                  'Name', 'Channel Identification',  ...
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
                    'Position', [0.79 0.02 0.18 0.05], ...
                    'String', 'OK',  ...
                    'Tag', 'pushbutton11');
    enabled = [enabled hOK];

    % The Add and Remove buttons
    hAdd = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @add_channel_Callback, ...
                    'Position', [0.01 0.055 0.1 0.04], ...
                    'String', 'Add channel',  ...
                    'Tag', 'pushbutton12');
    enabled = [enabled hAdd];

    hRemove = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Callback', @remove_channel_Callback, ...
                    'Position', [0.01 0.01 0.1 0.04], ...
                    'String', 'Remove channel',  ...
                    'Tag', 'pushbutton13');
    enabled = [enabled hRemove];

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
                    'Max', nframes-1, ...
                    'Min', 1, ...
                    'Style', 'slider', ...
                    'Tag', 'slider');
    enabled = [enabled hFrame];

    %%%%%%% Now the main panel

    % The panel itsel
    hPanel = uipanel('Parent', hFig, ...
                     'Title', 'Channel 1',  ...
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
                         'String', 'Filtered image', ...
                         'Tag', 'radio11');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.4 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Raw image', ...
                         'Tag', 'radio12');
    enabled = [enabled hControl];

    hControl = uicontrol('Parent', hRadio, ...
                         'Units', 'normalized',  ...
                         'Position', [0.7 0.1 0.25 0.8], ...
                         'Style', 'radiobutton',  ...
                         'String', 'Difference', ...
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
                         'String', 'Current frame', ...
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
                         'String', 'Difference', ...
                         'Tag', 'radio23');
    enabled = [enabled hControl];

    % The type, color and compression of the channel, along with its labels
    hText = uicontrol('Parent', hPanel, ...
                      'Units', 'normalized',  ...
                      'Position', [0.9 0.925 0.05 0.05], ...
                      'String', 'Channel:',  ...
                      'FontSize', 12, ...
                      'FontWeight', 'bold', ...
                      'Style', 'text',  ...
                      'Tag', 'text16');

    hText = uicontrol('Parent', hPanel, ...
                      'Units', 'normalized',  ...
                      'Position', [0.9 0.875 0.05 0.05], ...
                      'String', 'Type',  ...
                      'Style', 'text',  ...
                      'Tag', 'text17');

    hType = uicontrol('Parent', hPanel, ...
                      'Units', 'normalized',  ...
                      'Callback', @gui_Callback, ...
                      'Position', [0.875 0.845 0.1 0.05], ...
                      'String', typestring, ...
                      'Style', 'popupmenu',  ...
                      'Value', 1, ...
                      'Tag', 'type');
    enabled = [enabled hType];

    hText = uicontrol('Parent', hPanel, ...
                      'Units', 'normalized',  ...
                      'Position', [0.9 0.79 0.05 0.05], ...
                      'String', 'Color',  ...
                      'Style', 'text',  ...
                      'Tag', 'text18');

    hColor = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @gui_Callback, ...
                       'Position', [0.9 0.765 0.05 0.05], ...
                       'Style', 'pushbutton',  ...
                       'FontSize', 80, ...
                       'String', 'Fluorophore color',  ...
                       'Tag', 'color');
    enabled = [enabled hColor];

    hText = uicontrol('Parent', hPanel, ...
                      'Units', 'normalized',  ...
                      'Position', [0.89 0.69 0.075 0.05], ...
                      'String', 'Compression',  ...
                      'Style', 'text',  ...
                      'Tag', 'text19');

    hCompress = uicontrol('Parent', hPanel, ...
                          'Units', 'normalized',  ...
                          'Callback', @gui_Callback, ...
                          'Position', [0.89 0.655 0.075 0.05], ...
                          'String', typecompress, ...
                          'Style', 'popupmenu',  ...
                          'Value', 1, ...
                          'Tag', 'compression');
    enabled = [enabled hCompress];

    % The various filters, along with their labels
    hText = uicontrol('Parent', hPanel, ...
                      'Units', 'normalized',  ...
                      'Position', [0.9 0.525 0.05 0.05], ...
                      'String', 'Filters:',  ...
                      'FontSize', 12, ...
                      'FontWeight', 'bold', ...
                      'Style', 'text',  ...
                      'Tag', 'text16');

    hDetrend = uicontrol('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'Callback', @gui_Callback, ...
                         'Position', [0.9 0.5 0.1 0.05], ...
                         'String', 'Detrend',  ...
                         'Style', 'checkbox',  ...
                         'Tag', 'detrend');
    enabled = [enabled hDetrend];

    hCosmics = uicontrol('Parent', hPanel, ...
                           'Units', 'normalized',  ...
                           'Callback', @gui_Callback, ...
                           'Position', [0.9 0.45 0.1 0.05], ...
                           'String', 'Cosmic rays',  ...
                           'Style', 'checkbox',  ...
                           'Tag', 'cosmics');
    enabled = [enabled hCosmics];

    hHotPixels = uicontrol('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'Callback', @gui_Callback, ...
                         'Position', [0.9 0.4 0.1 0.05], ...
                         'String', 'Hot pixels',  ...
                         'Style', 'checkbox',  ...
                         'Tag', 'hot_pixels');
    enabled = [enabled hHotPixels];

    hNorm = uicontrol('Parent', hPanel, ...
                           'Units', 'normalized',  ...
                           'Callback', @gui_Callback, ...
                           'Position', [0.9 0.35 0.1 0.05], ...
                           'String', 'Normalize',  ...
                           'Style', 'checkbox',  ...
                           'Tag', 'normalize');
    enabled = [enabled hNorm];

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
                     'detrend', hDetrend, ...
                     'list', hChannel, ...
                     'hot_pixels', hHotPixels, ...
                     'cosmics', hCosmics, ...
                     'normalize', hNorm, ...
                     'channel_color', hColor, ...
                     'channel_type', hType, ...
                     'compress', hCompress, ...
                     'axes', [hAxes hAxesNext], ...
                     'experiment', hName, ...
                     'all_buttons', enabled, ...
                     'img', -1, ...
                     'prev_frame', -1, ...
                     'frame', 1, ...
                     'display', [1 1], ...
                     'prev_channel', -1, ...
                     'current', 1);

    return;
  end
end
