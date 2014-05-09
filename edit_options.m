function mystruct = edit_options(mystruct, name)

  if (nargin == 1)
    name = '';
  end

  values = parse_struct(mystruct);
  hFig = create_figure(values);

  uiwait(hFig);
  delete(hFig);

  return;

  function hFig = create_figure(myvals)

    if (isempty(name))
      ftitle = 'Edit options';
    else
      ftitle = ['Edit options (' name ')'];
    end

    hFig = figure('PaperUnits', 'centimeters',  ...
                  'CloseRequestFcn', @empty, ...
                  'Color',  [0.7 0.7 0.7], ...
                  'MenuBar', 'none',  ...
                  'Name', ftitle,  ...
                  'Resize', 'off', ...
                  'NumberTitle', 'off',  ...
                  'Units', 'normalized', ...
                  'Position', [0.3 0.25 .35 0.5], ...
                  'DeleteFcn', @empty, ...
                  'WindowScrollWheelFcn', @scrolling, ...
                  'HandleVisibility', 'callback',  ...
                  'Tag', 'main_fig',  ...
                  'UserData', [], ...
                  'Visible', 'off');

    hSlider = uicontrol('Parent', hFig, ...
                  'Units', 'normalized',  ...
                  'Callback', @slider_Callback, ...
                  'Position', [0.15 0 0.05 1], ...
                  'Value', 0, ...
                  'Max', 1, ...
                  'Min', 0, ...
                  'Style', 'slider', ...
                  'Tag', 'slider1');

    hPanel = uipanel('Parent', hFig, ...
                     'Title', '',  ...
                     'Units', 'normalized', ...
                     'Tag', 'uipanel',  ...
                     'Clipping', 'on',  ...
                     'Position', [0.2 0 0.8 1]);

    hOK = uicontrol('Parent', hFig, ...
                  'Units', 'normalized',  ...
                  'Callback', @save_CloseRequestFcn, ...
                  'Position', [0.025 0.85 0.1 0.1], ...
                  'String', 'OK',  ...
                  'Tag', 'okbutton');

    hCancel = uicontrol('Parent', hFig, ...
                  'Units', 'normalized',  ...
                  'Callback', @cancel_CloseRequestFcn, ...
                  'Position', [0.025 0.75 0.1 0.1], ...
                  'String', 'Cancel',  ...
                  'Tag', 'okbutton');

    set(hPanel, 'Units', 'Pixels');
    psize = get(hPanel, 'Position');

    fields = NaN(size(myvals, 1), 1);

    count = 0;
    for i=size(myvals,1):-1:1

      curr_size = get(hPanel, 'Position');
      if (count*50 + 70 > curr_size(4))
        set(hPanel, 'Position', curr_size+[0 -50 0 50]);
      end

      hText = uicontrol('Parent', hPanel, ...
                        'Units', 'pixels',  ...
                        'Position', [20 count*50 + 20 120 30], ...
                        'String', myvals{i,1},  ...
                        'Style', 'text',  ...
                        'Tag', 'text');

      switch myvals{i,4}
        case 'edit'
          hControl = uicontrol('Parent', hPanel, ...
                        'Units', 'pixels',  ...
                        'Position', [180 count*50 + 30 180 40], ...
                        'BackgroundColor', [1 1 1], ...
                        'String', myvals{i,2}, ...
                        'Style', myvals{i,4}, ...
                        'Tag', 'data');
        case 'checkbox'
          hControl = uicontrol('Parent', hPanel, ...
                        'Units', 'pixels',  ...
                        'Position', [180 count*50 + 30 180 40], ...
                        'Value', myvals{i,2}, ...
                        'Style', myvals{i,4}, ...
                        'Tag', 'data');
        case 'table'
          ncolumns = size(myvals{i,2}, 2);
          hControl = uitable('Parent', hPanel, ...
                        'Units', 'pixels',  ...
                        'Position', [180 count*50 + 30 180 80], ...
                        'ColumnEditable', true(1, ncolumns), ...
                        'Data', myvals{i,2}, ...
                        'ColumnName', [], ...
                        'RowName', [], ...
                        'Tag', 'data');

          set(hText, 'Position', [20 count*50 + 50 120 30]);

          count = count + 1;

          if (strncmp(myvals{i,3}, 'strel', 5))
            set(hControl, 'Position', [180 (count-1)*50 + 30 180 120], ...
                          'ColumnWidth', repmat({20}, 1, ncolumns));
            set(hText, 'Position', [20 count*50 + 50 120 30]);

            count = count + 1;
          end
        case 'button'
          hControl = uicontrol('Parent', hPanel, ...
                        'Units', 'pixels',  ...
                        'Position', [180 count*50 + 30 180 40], ...
                        'String', 'edit structure', ...
                        'Callback', @recursive_edit, ...
                        'Style', 'pushbutton', ...
                        'Tag', myvals{i,1});
      end

      count = count + 1;
      fields(i) = hControl;
    end
    curr_size = get(hPanel, 'Position');
    if (count*50 + 30 > curr_size(4))
      diff_size = curr_size(4) - (count*50 + 30);
      set(hPanel, 'Position', curr_size+[0 diff_size 0 -diff_size]);
    end

    curr_size = get(hPanel, 'Position');
    if (curr_size(4) - psize(4) < 1)
      set(hSlider, 'Visible', 'off');
    else
      set(hSlider, 'Max', curr_size(4) - psize(4), 'Value', curr_size(4) - psize(4));
    end

    handles = struct('panel', hPanel, ...
                     'controls', fields, ...
                     'fix_offset', psize(2), ...
                     'slider', hSlider);

    set(hFig, 'UserData', handles, ...
              'Visible', 'on');

    return;
  end

  function empty(hObject, eventdata, handles)
    return;
  end

  function cancel_CloseRequestFcn(hObject, eventdata, handles)
    uiresume(gcbf)

    return;
  end

  function scrolling(hObject, scroll_struct)

    move = 2*scroll_struct.VerticalScrollCount * scroll_struct.VerticalScrollAmount;

    handles = get(hFig, 'UserData');

    %# slider value
    offsets = get(handles.slider, {'Value', 'Min', 'Max'});
    new_offset = offsets{1} - move;
    new_offset = max(new_offset, offsets{2});
    new_offset = min(new_offset, offsets{3});

    set(handles.slider,'Value', new_offset);

    %# update panel position
    p = get(handles.panel, 'Position');  %# panel current position
    set(handles.panel, 'Position',[p(1) -new_offset+handles.fix_offset p(3) p(4)])

    return;
  end

  function recursive_edit(hObject, eventdata, handles)

    set(hFig, 'Visible', 'off');
    fieldname = get(hObject, 'Tag');

    if (isempty(name))
      fname = fieldname;
    else
      fname = [name '.' fieldname];
    end

    value = edit_options(mystruct.(fieldname), fname);
    mystruct.(fieldname) = value;
    set(hFig, 'Visible', 'on');

    return
  end

  function slider_Callback(hObject, eventdata, handles)

    handles = get(hFig, 'UserData');

    %# slider value
    offset = get(handles.slider,'Value');

    %# update panel position
    p = get(handles.panel, 'Position');  %# panel current position
    set(handles.panel, 'Position',[p(1) -offset+handles.fix_offset p(3) p(4)])

    return
  end

  function save_CloseRequestFcn(hObject, eventdata, handles)

    handles = get(hFig, 'UserData');

    for i=1:size(values, 1)
      switch values{i,4}
        case 'edit'
          val = get(handles.controls(i), 'String');
        case 'checkbox'
          val = logical(get(handles.controls(i), 'Value'));
        case 'table'
          val = get(handles.controls(i), 'Data');
        otherwise
          continue;
      end

      if (~isempty(val))
        switch values{i,3}
          case 'cell'
            goods = ~cellfun('isempty', val)
            grow = any(goods, 1);
            gcol = any(goods, 2);
            val = val(grow, gcol);
          case 'num'
            [tmp, correct] = mystr2double(val);
            while (~correct)
              answer = inputdlg(['''' values{i,1} ''' is not a valid number, do you want to correct it ?'], 'Correct a numerical value', 1, {val});
              if (isempty(answer))
                [tmp, correct] = mystr2double(values{i, 2});
              else
                [tmp, correct] = mystr2double(answer{1});
              end
            end

            val = tmp;
          case 'func'
            [tmp, correct] = mystr2func(val);

            while (~correct)
              if (iscell(val))
                val = char(val(~cellfun('isempty', val)));
                val = [val repmat(' ', size(val, 1), 1)];
                val = val.';
                val = strtrim(val(:).');
              end

              answer = inputdlg(['''' values{i,1} ''' is not a valid function, do you want to correct it ?'], 'Correct a function handle', 1, {val});
              if (isempty(answer))
                [tmp, correct] = mystr2func(values{i, 2});
              else
                [tmp, correct] = mystr2func(answer{1});
              end
            end

            val = tmp;
          case 'strel'
            val = strel('arbitrary', val);
        end
      end

      mystruct.(values{i,1}) = val;
    end

    uiresume(gcbf)

    return
  end
end

function [values, correct] = mystr2func(value)

  if (iscell(value))
    splits = value;
    splits = splits(~cellfun('isempty', splits));
  else
    splits = regexp(value, '\s+', 'split');
  end
  values = cellfun(@str2func, splits, 'UniformOutput', false);

  implicit = cellfun(@(x)(x(1) == '@'), splits);
  explicit = cellfun(@(x)(~isempty(which(x))), splits);
  correct = all(implicit | explicit);

  return;
end

function [values, correct] = mystr2double(value)

  splits = regexp(value, '\s+', 'split');
  values = str2double(splits);
  nans = cellfun(@(x)(strncmpi(x, 'nan', 3)), splits);
  correct = ~any(isnan(values) & ~nans);

  return;
end

function values = parse_struct(mystruct)

  fields = fieldnames(mystruct);
  values = cell(length(fields), 4);

  for i=1:length(fields)
    field = fields{i};
    val = mystruct.(field);

    values{i, 1} = field;
    values{i, 2} = val;

    switch class(val)

      case {'double', 'single', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'}
        values{i, 3} = 'num';
        values{i, 4} = 'edit';
        values{i, 2} = num2str(values{i,2}(:).');
      case 'char'
        values{i, 3} = 'char';
        values{i, 4} = 'edit';
      case 'cell'
        if (~isempty(val) & strncmp(class(val{1}), 'function_handle', 15))
          values{i, 3} = 'func';
          values{i, 4} = 'table';

          tmp_cell = repmat({''}, size(val)+5);
          tmp_cell(1:numel(val)) = cellfun(@(x){func2str(x)}, val);
          values{i, 2} = tmp_cell;
        else
          values{i, 3} = 'cell';
          values{i, 4} = 'table';

          tmp_cell = repmat({''}, size(val)+5);
          tmp_cell(1:numel(val)) = val;
          values{i, 2} = tmp_cell;
        end
      case 'struct'
        values{i, 3} = 'struct';
        values{i, 4} = 'button';
      case 'logical'
        values{i, 3} = 'bool';
        values{i, 4} = 'checkbox';
        values{i, 2} = double(values{i, 2});
      case 'function_handle'
        values{i, 3} = 'func';
        values{i, 4} = 'edit';
        values{i, 2} = func2str(values{i, 2});
      case 'strel'
        values{i, 3} = 'strel';
        values{i, 4} = 'table';
        values{i, 2} = getnhood(values{i, 2});
      otherwise
        values{i, 3} = class(val);
    end
  end

  return;
end
