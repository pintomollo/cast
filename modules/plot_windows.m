function hgroup = plot_windows(h, spots, color, mark_center)
% PLOT_WINDOWS draws estimation windows as rectangles.
%
%   HGROUP = PLOT_WINDOWS(WINDOWS) draws all WINDOWS in the current axes, returning a
%   handler to the hggroup HGROUP containing the rectangles. WINDOWS should contain
%   one row per window, ordered as [X_coord, Y_coord, width, height, ...]. WINDOWS are
%   drawn with a size of 2*[width height] + 1.
%
%   HGROUP = PLOT_WINDOWS(WINDOWS_GROUPS) plots several layers of windows, group by
%   group, in the reverse order of the cell vector WINDOWS_GROUPS (e.g. different
%   frames).
%
%   HGROUP = PLOT_WINDOWS(..., COLORS) defines the color to be used for the rectangles.
%   If several groups of windows are to be drawn, a vector/matrix of colors can be
%   provided. Default value is 'r'.
%
%   HGROUP = PLOT_WINDOWS(HGROUP, ...) draws the windows in the provided HGROUP,
%   replacing existing rectangles (usually faster than creating a new group).
%
%   HGROUP = PLOT_WINDOWS(HAXES, ...) draws the hggroup in the axes defined by HAXES.
%
% Gonczy & Naef labs, EPFL
% Simon Blanchoud
% 31.03.2015

  % Input checking and default values
  if (nargin == 1)
    spots = h;
    h = gca;
    color = 'r';
    mark_center = false;
  elseif (nargin == 2)
    color = 'r';
    mark_center = false;
  elseif (nargin == 3)
    mark_center = false;
  end

  if (~ishandle(h))
    if (islogical(spots))
      mark_center = spots;
    else
      color = spots;
    end
    spots = h;
    h = gca;
  end

  if (islogical(color))
    tmp = color;
    color = mark_center;
    mark_center = tmp;
  end

  % For simplicity, we always work with cell arrays
  if (~iscell(spots))
    spots = {spots};
  end

  % Check the number of groups and adapt the number of colors accordingly
  ngroups = length(spots);
  if (ischar(color))
    color = [color, color(ones(1, ngroups-length(color)))];
    color = color(1:ngroups);
  else
    color = [color; color(ones(1, ngroups-size(color,1)),:)];
    color = color(1:ngroups,:);
  end

  % Check if we got an hggroup directly or if we need to create one
  if (strncmp(get(h, 'Type'), 'hggroup',7))
    hgroup = h;
  else
    hgroup = hggroup('Parent', h);
  end

  % Get the handler to our parent axes
  haxes = get(hgroup, 'Parent');

  % Change the current "hold" status, so we can draw several circles together
  status = get(haxes, 'NextPlot');
  set(haxes,'NextPlot', 'add');

  % Get the handlers and the number of existing circles in the hggroup
  hrects = get(hgroup, 'Children');
  nrects = length(hrects);

  % We draw a rectangle
  rectang = [-1 1 1 -1; -1 -1 1 1];
  rectang = rectang(:, [1:end 1]);

  % Need to remember how many circles we have drawn in total
  count = 0;

  % Loog over all groups backwards, to have the "first" ones on top.
  for g = ngroups:-1:1

    % The spots of the current group, exclusing totally NaN ones
    curr_spots = spots{g};
    curr_spots = curr_spots(any(~isnan(curr_spots),2),:);

    % Get the current color
    if (ischar(color))
      curr_color = color(g);
    else
      curr_color = color(g,:);
    end

    % Prepare the handlers array
    nspots = size(curr_spots, 1);
    handles = NaN(nspots, 1);

    % Loop over all spots
    for s = 1:nspots

      % Scale and translate the rectangle to the current spot
      pos = bsxfun(@plus, curr_spots(s, 1:2).', ...
                    bsxfun(@times, rectang, curr_spots(s, 3:4).'));

      if (mark_center)
        indx = (s-1)*2 + 1;

        % If we ran out of existing rectangles to modify, creat a new one
        if (count + indx > nrects)
          handles(count + indx) = line('XData', pos(1,:), 'YData', pos(2,:), 'Parent', hgroup, ...
                            'Color', curr_color, 'Marker', 'none');

        % Otherwise, modify the required data, and store the previous handler
        else
          set(hrects(count + indx), 'XData', pos(1,:), 'YData', pos(2,:), 'Color', curr_color, 'Marker', 'none');
          handles(indx) = hrects(count + indx);
        end

        % If we ran out of existing rectangles to modify, creat a new one
        if (count + indx + 1 > nrects)
          handles(count + indx + 1) = line('XData', curr_spots(s,1), 'YData', curr_spots(s,2), 'Parent', hgroup, ...
                            'Color', curr_color, 'Marker', 'd');

        % Otherwise, modify the required data, and store the previous handler
        else
          set(hrects(count + indx + 1), 'XData', curr_spots(s,1), 'YData', curr_spots(s,2), 'Color', curr_color, 'Marker', 'd');
          handles(indx + 1) = hrects(count + indx + 1);
        end
      else
        % If we ran out of existing rectangles to modify, creat a new one
        if (count+s > nrects)
          handles(s) = line('XData', pos(1,:), 'YData', pos(2,:), 'Parent', hgroup, ...
                            'Color', curr_color, 'Marker', 'none');

        % Otherwise, modify the required data, and store the previous handler
        else
          set(hrects(count+s), 'XData', pos(1,:), 'YData', pos(2,:), 'Color', curr_color, 'Marker', 'none');
          handles(s) = hrects(count+s);
        end
      end
    end

    % Update the total number of drawn rectangles
    if (mark_center)
      count = count + 2*nspots;
    else
      count = count + nspots;
    end

    % Bring the current group on top, in that sense, the last ones will be on top !
    goods = ishandle(handles);
    if (any(goods))
      uistack(handles(goods), 'top');
    end
  end

  % Set back the status
  set(haxes,'NextPlot', status);

  % Delete additional previous rectangles
  delete(hrects(count+1:nrects))

  % Prevent the output if not needed
  if (nargout == 0)
    clearvars
  end

  return;
end
