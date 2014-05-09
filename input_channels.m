function channels = input_channels(fname)
% INPUT_CHANNELS displays a pop-up window for the user to manually identify the
% type of data contained in the different channels of a movie recording.
%
%   [CHANNELS] = INPUT_CHANNELS(CHANNELS) displays the window using the data
%   contained in CHANNELS, updates it accordingly to the user's choice and returns.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 20.05.2011

  if (nargin == 0 | isempty(fname))
    fname = convert_movie();
    fname = {fname};
  elseif (~iscell(fname))
    fname = {fname};
  end

  nchannels = length(fname);
  channels = get_struct('channel', [nchannels 1]);
  for i=1:nchannels
    channels(i).fname = fname{i};
  end

  % Initialize the size of the movie, the possible types and compressions
  typestring = {'luminescence';'brightfield'; 'dic'; 'fluorescence'};
  %writer = loci.formats.out.OMETiffWriter;
  %typecompress = cell(writer.getCompressionTypes());
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
      channels(i).type = 1;
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

  nframes = size_data(channels(1).fname);
  exp_name = channels(1).fname;
  [junk, exp_name, junk] = fileparts(exp_name);
  [junk, exp_name, junk] = fileparts(exp_name);
  exp_name = regexprep(exp_name, ' ', '');

  % Create my own grayscale map for the image display
  mygray = [0:255]' / 255;
  mygray = [mygray mygray mygray];

  enabled = [];

  hFig = figure('PaperUnits', 'centimeters',  ...
                'CloseRequestFcn', @channel_fig_CloseRequestFcn, ...
                'Color',  [0.7 0.7 0.7], ...
                'Colormap', mygray, ...
                'MenuBar', 'none',  ...
                'Name', 'Channel Identification',  ...
                'NumberTitle', 'off',  ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'DeleteFcn', @empty, ...
                'HandleVisibility', 'callback',  ...
                'Tag', 'channel_fig',  ...
                'UserData', [], ...
                'Visible', 'off');

  hOK = uicontrol('Parent', hFig, ...
                  'Units', 'normalized',  ...
                  'Callback', @channel_fig_CloseRequestFcn, ...
                  'Position', [0.79 0.02 0.18 0.05], ...
                  'String', 'OK',  ...
                  'Tag', 'pushbutton11');
  enabled = [enabled hOK];

  hAdd = uicontrol('Parent', hFig, ...
                  'Units', 'normalized',  ...
                  'Callback', @channel_Callback, ...
                  'Position', [0.01 0.02 0.15 0.05], ...
                  'String', 'Add channel',  ...
                  'Tag', 'pushbutton12');
  enabled = [enabled hAdd];

  hText = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Position', [0.25 0.93 0.09 0.025], ...
                    'String', 'Experiment name:',  ...
                    'BackgroundColor', get(hFig, 'Color'), ...
                    'FontSize', 12, ...
                    'Style', 'text',  ...
                    'Tag', 'text1');

  hName = uicontrol('Parent', hFig, ...
                    'Units', 'normalized',  ...
                    'Position', [0.35 0.93 0.5 0.05], ...
                    'String', exp_name,  ...
                    'FontSize', 12, ...
                    'Style', 'edit',  ...
                    'Tag', 'edit1');
  enabled = [enabled hName];

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
                  'Callback', @slider_Callback, ...
                  'Position', [0.3 0.03 0.35 0.025], ...
                  'Value', 1, ...
                  'SliderStep', [1 10]/nframes, ...
                  'Max', nframes, ...
                  'Min', 1, ...
                  'Style', 'slider', ...
                  'Tag', 'slider1');
  enabled = [enabled hFrame];

  hPanel = uipanel('Parent', hFig, ...
                   'Title', 'Channel 1',  ...
                   'Tag', 'uipanel',  ...
                   'Clipping', 'on',  ...
                   'Position', [0.17 0.11 0.81 0.8]);

  hAxes = axes('Parent', hPanel, ...
               'Position', [0.05 0.03 0.56 0.97], ...
               'Visible', 'off',  ...
               'Tag', 'axes');

  hName = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Position', [0.63 0.67 0.29 0.29], ...
                    'String', 'filename',  ...
                    'Style', 'text',  ...
                    'Tag', 'fname');

  hDetrend = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @detrend_Callback, ...
                       'Position', [0.70 0.09 0.17 0.09], ...
                       'String', 'Detrend',  ...
                       'Style', 'checkbox',  ...
                       'Tag', 'detrend');
  enabled = [enabled hDetrend];

  hCosmics = uicontrol('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'Callback', @cosmics_Callback, ...
                         'Position', [0.70 0.01 0.17 0.09], ...
                         'String', 'Cosmic rays',  ...
                         'Style', 'checkbox',  ...
                         'Tag', 'cosmics');
  enabled = [enabled hCosmics];


  hHotPixels = uicontrol('Parent', hPanel, ...
                       'Units', 'normalized',  ...
                       'Callback', @hotpix_Callback, ...
                       'Position', [0.85 0.09 0.17 0.09], ...
                       'String', 'Hot pixels',  ...
                       'Style', 'checkbox',  ...
                       'Tag', 'hot_pixels');
  enabled = [enabled hHotPixels];

  hNorm = uicontrol('Parent', hPanel, ...
                         'Units', 'normalized',  ...
                         'Callback', @norm_Callback, ...
                         'Position', [0.85 0.01 0.17 0.09], ...
                         'String', 'Normalize',  ...
                         'Style', 'checkbox',  ...
                         'Tag', 'normalize');
  enabled = [enabled hNorm];

  hColor = uicontrol('Parent', hPanel, ...
                     'Units', 'normalized',  ...
                     'Callback', @channel_color_Callback, ...
                     'Position', [0.68 0.60 0.21 0.11], ...
                     'Style', 'pushbutton',  ...
                     'FontSize', 80, ...
                     'String', 'Fluorophore color',  ...
                     'Tag', 'channel_color');
  enabled = [enabled hColor];

  hType = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Callback', @channel_type_Callback, ...
                    'Position', [0.665 0.40 0.24 0.08], ...
                    'String', typestring, ...
                    'Style', 'popupmenu',  ...
                    'Value', 1, ...
                    'Tag', 'channel_type');
  enabled = [enabled hType];

  hCompress = uicontrol('Parent', hPanel, ...
                        'Units', 'normalized',  ...
                        'Callback', @compress_type_Callback, ...
                        'Position', [0.665 0.205 0.24 0.08], ...
                        'String', typecompress, ...
                        'Style', 'popupmenu',  ...
                        'Value', 1, ...
                        'Tag', 'channel_type');
  enabled = [enabled hCompress];

  hChannel = uicontrol('Parent', hFig, ...
                       'Units', 'normalized',  ...
                       'Callback', @list_Callback, ...
                       'Position', [0.01 0.11 0.15 0.79], ...
                       'String', liststring, ...
                       'Style', 'listbox',  ...
                       'Value', 1, ...
                       'Tag', 'channel_list');
  enabled = [enabled hChannel];

  hText = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Position', [0.68 0.5 0.20 0.05], ...
                    'String', 'Channel type',  ...
                    'Style', 'text',  ...
                    'Tag', 'text18');

  hText = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Position', [0.68 0.3 0.20 0.05], ...
                    'String', 'Compression type',  ...
                    'Style', 'text',  ...
                    'Tag', 'text19');

  hText = uicontrol('Parent', hPanel, ...
                    'Units', 'normalized',  ...
                    'Position', [0.68 0.72 0.20 0.05], ...
                    'String', 'Channel color',  ...
                    'Style', 'text',  ...
                    'Tag', 'text17');

  handles = struct('uipanel', hPanel, ...
                   'fname', hName, ...
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
                   'axes', hAxes, ...
                   'channels', channels, ...
                   'all_buttons', enabled, ...
                   'img', -1, ...
                   'frame', 1, ...
                   'current', 1);

  set(hFig, 'UserData',  handles);
  set(hFig,'Visible', 'on');
  update_display(hFig, 1, 1);

  uiwait(hFig);

  handles = get(hFig, 'UserData');
  channels = handles.channels;

  delete(hFig);
  drawnow;

  return;

  function empty(hObject, eventdata, handles)
    return
  end

  function list_Callback(hObject, eventdata, handles)
  % hObject    handle to channel_list (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hints: contents = get(hObject,'String') returns channel_list contents as cell array
  %        contents{get(hObject,'Value')} returns selected item from channel_list

    update_display(gcbf, get(hObject,'Value'));
    return
  end

  % -- Update the display
  function update_display(hfig, indx, nimg)

  handles = get(hfig,'UserData');

  handles.current = indx;
  if (nargin == 3)
    handles.frame = nimg;
  else
    nimg = handles.frame;
  end
  set(handles.uipanel,'Title', ['Channel ' num2str(indx)]);
  set(handles.fname,'String', handles.channels(indx).file);
  set(handles.detrend,'Value', handles.channels(indx).detrend);
  set(handles.hot_pixels,'Value', handles.channels(indx).hot_pixels);
  set(handles.normalize,'Value', handles.channels(indx).normalize);
  set(handles.cosmics,'Value', handles.channels(indx).cosmics);
  rgb_color = round(handles.channels(indx).color * 255);
  set(handles.channel_color, 'String', ['<HTML><BODY bgcolor = "rgb(' num2str(rgb_color(1)) ', ' num2str(rgb_color(2)) ', ' num2str(rgb_color(3)) ')">green background</BODY></HTML>'])
  set(handles.channel_color, 'ForegroundColor', handles.channels(indx).color);
  set(handles.channel_type, 'Value',  handles.channels(indx).type);
  set(handles.compress, 'Value',  handles.channels(indx).compression);
  set(handles.text, 'String', ['Frame #' num2str(nimg)]);

  set(handles.all_buttons, 'Enable', 'off');
  drawnow;
  refresh(hfig);

  img = double(load_data(handles.channels(indx).fname, nimg));

  if (handles.channels(indx).detrend)
    img = imdetrend(img);
  end

  if (handles.channels(indx).cosmics)
    img = imcosmics(img);
  end

  if (handles.channels(indx).hot_pixels)
    img = imhotpixels(img);
  end

  if (handles.channels(indx).normalize)
    img = imnorm(img);
  end

  if (ishandle(handles.img))
    set(handles.img,'CData', img);
  else
    %cmap = colormap('gray');
    %image(load_data(handles.channels(indx),1),'Parent', handles.axes);
    %image(load_data(handles.channels(indx),1),'Parent', handles.axes,'CDataMapping', 'scaled', 'Visible', 'on');
    %axes(handles.axes);
    %get(handles.axes,'type')
    

    handles.img = image(img,'Parent', handles.axes,'CDataMapping', 'scaled');
    %aspect(handles.axes, [aspect_ratio]);
    set(handles.axes,'Visible', 'off',  ...
               'DataAspectRatio',  [1 1 1]);
  end

  set(handles.all_buttons, 'Enable', 'on');

  set(hfig, 'UserData',  handles);
    return
  end

  % --- Executes on button press in detrend.
  function channel_Callback(hObject, eventdata, handles)
  % hObject    handle to detrend (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hint: get(hObject,'Value') returns toggle state of detrend

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  set(handles.all_buttons, 'Enable', 'off');

  new_channel = convert_movie()

  if (~isempty(new_channel))
    handles.channels(end+1) = get_struct('channel');
    handles.channels(end).fname = new_channel;
    handles.channels(end).type = 1;
    handles.channels(end).compression = 1;

    liststring = [get(handles.list, 'String') '|Channel ' num2str(length(handles.channels))];
    set(handles.list, 'String', liststring);
  end

  set(handles.all_buttons, 'Enable', 'on');

  set(hfig, 'UserData',  handles);

    return
  end

  % --- Executes on button press in detrend.
  function detrend_Callback(hObject, eventdata, handles)
  % hObject    handle to detrend (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hint: get(hObject,'Value') returns toggle state of detrend

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  handles.channels(handles.current).detrend = logical(get(hObject, 'Value'));
  set(hfig, 'UserData',  handles);

  update_display(hfig, handles.current);
    return
  end

  % --- Executes on button press in detrend.
  function norm_Callback(hObject, eventdata, handles)
  % hObject    handle to detrend (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hint: get(hObject,'Value') returns toggle state of detrend

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  handles.channels(handles.current).normalize = logical(get(hObject, 'Value'));
  set(hfig, 'UserData',  handles);

  update_display(hfig, handles.current);
    return
  end


  % --- Executes on button press in detrend.
  function cosmics_Callback(hObject, eventdata, handles)
  % hObject    handle to detrend (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hint: get(hObject,'Value') returns toggle state of detrend

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  handles.channels(handles.current).cosmics = logical(get(hObject, 'Value'));
  set(hfig, 'UserData',  handles);

  update_display(hfig, handles.current);
    return
  end


  % --- Executes on button press in detrend.
  function slider_Callback(hObject, eventdata, handles)
  % hObject    handle to detrend (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hint: get(hObject,'Value') returns toggle state of detrend

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  nimg = round(get(hObject, 'Value'));

  update_display(hfig, handles.current, nimg);
    return
  end

  % --- Executes on button press in detrend.
  function hotpix_Callback(hObject, eventdata, handles)
  % hObject    handle to detrend (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hint: get(hObject,'Value') returns toggle state of detrend

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  handles.channels(handles.current).hot_pixels = logical(get(hObject, 'Value'));
  set(hfig, 'UserData',  handles);

  update_display(hfig, handles.current);
    return
  end

  % --- Executes on button press in channel_color.
  function channel_color_Callback(hObject, eventdata, handles)
  % hObject    handle to channel_color (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  indx = handles.current;

  handles.channels(indx).color = uisetcolor(handles.channels(indx).color);

  set(handles.channel_color, 'ForegroundColor',  handles.channels(indx).color);
  rgb_color = round(handles.channels(indx).color * 255);
  set(handles.channel_color, 'String', ['<HTML><BODY bgcolor = "rgb(' num2str(rgb_color(1)) ', ' num2str(rgb_color(2)) ', ' num2str(rgb_color(3)) ')">green background</BODY></HTML>'])

  set(hfig, 'UserData',  handles);
    return
  end

  % --- Executes on selection change in channel_type.
  function compress_type_Callback(hObject, eventdata, handles)
  % hObject    handle to channel_type (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hints: contents = get(hObject,'String') returns channel_type contents as cell array
  %        contents{get(hObject,'Value')} returns selected item from channel_type

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  handles.channels(handles.current).compression = get(hObject, 'Value');
  set(hfig, 'UserData',  handles);
    return
  end


  % --- Executes on selection change in channel_type.
  function channel_type_Callback(hObject, eventdata, handles)
  % hObject    handle to channel_type (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  % Hints: contents = get(hObject,'String') returns channel_type contents as cell array
  %        contents{get(hObject,'Value')} returns selected item from channel_type

  hfig = gcbf;
  handles = get(hfig, 'UserData');
  handles.channels(handles.current).type = get(hObject, 'Value');
  set(hfig, 'UserData',  handles);
    return
  end

  function channel_fig_CloseRequestFcn(hObject, eventdata, handles)
  % hObject    handle to channel_fig (see GCBO)
  % eventdata  reserved - to be defined in a future version of MATLAB
  % handles    structure with handles and user data (see GUIDATA)

  hfig = gcbf;

  handles = get(hfig,'UserData');
  channels = handles.channels;
  nchannels = length(channels);

  contents = get(handles.channel_type,'String');
  ntypes = length(contents);
  compressions = get(handles.compress,'String');

  detrend = logical(zeros(nchannels,1));
  types = logical(zeros(nchannels,ntypes));
  colors = zeros(nchannels,3);

  for i=1:nchannels
    detrend(i) = channels(i).detrend;
    types(i,channels(i).type) = true;
    colors(i,:) = channels(i).color;
    channels(i).type = contents{channels(i).type};
    channels(i).compression = compressions{channels(i).compression};
  end

  ok = true;
  if (ok & any(detrend, 1))
    answer = questdlg('Some channels will be detrended, continue ?');
    ok = strcmp(answer,'Yes');
  end
  if (ok & size(unique(colors,'rows'),1)~=nchannels)
    answer = questdlg('Multiple channels have the same color, continue ?');
    ok = strcmp(answer,'Yes');
  end

  if (ok)
    handles.channels = channels;
    set(hfig,'UserData', handles);
    uiresume(hfig);
  end
    return
  end
end
