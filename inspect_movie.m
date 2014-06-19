function [mytracking, opts] = inspect_movie(mytracking, opts)
% INSPECT_MOVIE displays a pop-up window for the user to manually inspect the
% segmentation that will be performed on the provided movie.
%
%   [MYTRACKING, OPTS] = INSPECT_MOVIE(MYTRACKING,OPTS) displays the window using the
%   data contained in MYTRACKING and the parameter values from OPTS. It updates them
%   accordingly to the user's choice. MYTRACKING should be a 'mytracking' structure as
%   created by input_channels.m
%
%   [...] = INSPECT_MOVIE() prompts the user to select a MYTRACKING containing Matlab
%   file before opening the GUI.
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
    end
  end

  % Prepare some global variables
  channels = mytracking.channels;
  nchannels = length(channels);
  segmentations = get_struct('segmentation', nchannels);

  % Create the GUI using segmentations
  [hFig, handles] = create_figure(channels);

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

  % Store the segmentations
  mytracking.segmentations = segmentations;
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
      set(handles.uipanel,'Title', [channels(indx).type ' ' num2str(indx)]);

      % The filters
      set(handles.detrend,'Value', segmentations(indx).detrend);
      set(handles.denoise,'Value', segmentations(indx).denoise);

      % The type and compression
      set(handles.segmentation_type, 'Value',  segmentations(indx).type);
      set(handles.text, 'String', ['Frame #' num2str(nimg)]);

      % And setup the indexes correctly
      handles.prev_channel = indx;
      handles.prev_frame = -1;
    end

    % Here we recompute all the filtering of the frame
    if (recompute)
      % Because it takes long, display it and block the GUI
      set(hFig, 'Name', 'Images Segmentation (Processing...)');
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

      % Denoise the image ?
      if (segmentations(indx).denoise)
        %img = imdetrend(img, opts.filtering.detrend_meshpoints);
      end
    end

    % Determine which image to display in the left panel
    switch handles.display(1)

      % The raw image
      case 2
        img1 = orig_img;

      % The difference between filtered and raw
      case 3
        if (segmentations(indx).normalize)
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
    end

    % Release the image if need be
    if (recompute)
      set(hFig, 'Name', 'Images Segmentation');
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
      case {'detrend','denoise'}
        segmentations(indx).(type) = logical(get(hObject, 'Value'));

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
  % the segmentations structure for its standard form.

    % Create a copy of segmentations in case we need to cancel
    tmp_segmentations = segmentations;

    % We need ot loop over the segmentations
    nsegmentations = length(segmentations);

    % Get the available types of segmentations and compressions
    contents = get(handles.segmentation_type,'String');
    ntypes = length(contents);

    % We want to check if some segmentations have identical features
    denoise = logical(zeros(nsegmentations,1));
    detrend = logical(zeros(nsegmentations,1));
    types = logical(zeros(nsegmentations,ntypes));

    % Convert the indexes into strings and build a summary of the filters
    for i=1:nsegmentations
      denoise(i) = segmentations(i).denoise;
      detrend(i) = (segmentations(i).detrend && channels(i).detrend);
      types(i,segmentations(i).type) = true;
      tmp_segmentations(i).type = contents{segmentations(i).type};
    end

    % Some checks to make sure the user is aware of some potential issues
    ok = true;
    if (ok & any(detrend, 1))

      % This is slow process which have apparently already been applied
      answer = questdlg('Some channels will be detrended a second time, continue ?');
      ok = strcmp(answer,'Yes');
    end
    if (ok & any(sum(types(:,2:end), 1)>1))

      % Just in case, for later display
      answer = questdlg('Multiple channels will be segmented, continue ?');
      ok = strcmp(answer,'Yes');
    end

    % If everything is OK, release the GUI and quit
    if (ok)
      segmentations = tmp_segmentations;
      uiresume(hFig);
    end

    return
  end

  function [hFig, handles] = create_figure(channels)
  % This function actually creates the GUI, placing all the elements
  % and linking the calbacks.

    % The number of channels provided
    nchannels = length(channels);

    % Initialize the possible segmentations and their corresponding channels
    typestring = {'None','Spots ("A trous")', 'Nuclei'};
    typechannel = {'luminescence','fluorescence'};

    % Initialize the structure used for the interface
    liststring = '';
    for i = 1:nchannels

      % Build the displayed list
      liststring = [liststring channels(i).type num2str(i)];
      if (i < nchannels)
        liststring = [liststring '|'];
      end

      % Set the segmentation type
      type_test = ismember(typechannel, channels(i).type);
      if any(type_test)
        segmentations(i).type = find(type_test)+1;
      else
        segmentations(i).type = 1;
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
                  'Name', 'Images Segmentation',  ...
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
                     'Title', [channels(i).type '1'],  ...
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
                      'Position', [0.875 0.925 0.075 0.05], ...
                      'String', 'Segmentation:',  ...
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

    hDenoise = uicontrol('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'Callback', @gui_Callback, ...
                         'Position', [0.9 0.45 0.1 0.05], ...
                         'String', 'Denoise',  ...
                         'Style', 'checkbox',  ...
                         'Tag', 'denoise');
    enabled = [enabled hDenoise];

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
                     'denoise', hDenoise, ...
                     'list', hChannel, ...
                     'segmentation_type', hType, ...
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
