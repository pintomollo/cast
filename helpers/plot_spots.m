function hgroup = plot_spots(h, spots, color, mark_center)
% PLOT_SPOTS draws gaussian spots as circles proportional to their variance.
%
%   HGROUP = PLOT_SPOTS(SPOTS) draws all SPOTS in the current axes, returning a handler
%   to the hggroup HGROUP containing the circles. SPOTS should contain one row per
%   spot, ordered as [X_coord, Y_coord, sigma, ...]. SPOTS are drawn with a diameter
%   equal to 2*sigma. If the resulting diameter is smaller than 1 pix (or NaN), a
%   diameter of 1 is used instead.
%
%   HGROUP = PLOT_SPOTS(SPOTS_GROUPS) plots several layers of spots, group by group,
%   in the reverse order of the cell vector SPOTS_GROUPS (e.g. different frames).
%
%   HGROUP = PLOT_SPOTS(..., COLORS) defines the color to be used for the circle. If
%   several groups of spots are to be drawn, a vector/matrix of colors can be provided.
%   Default value is 'r'.
%
%   HGROUP = PLOT_SPOTS(HGROUP, ...) draws the circles in the provided HGROUP,
%   replacing existing circles (usually faster than creating a new group).
%
%   HGROUP = PLOT_SPOTS(HAXES, ...) draws the hggroup in the axes defined by HAXES.
%
% Gonczy and Naef labs, EPFL
% Simon Blanchoud
% 04.07.2014

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
  hcircls = get(hgroup, 'Children');
  ncircls = length(hcircls);

  % We draw a circle using complex coordinates
  complex_circle = exp(i*[0:0.1:2*pi]);
  complex_circle = complex_circle([1:end 1]);

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

      % Scale and translate the circle to the current spot
      pos = complex_circle*max(2*curr_spots(s,3), 1) + ...
            curr_spots(s,1) + i*curr_spots(s,2);

      if (mark_center)
        indx = (s-1)*2 + 1;

        % If we ran out of existing circles to modify, creat a new one
        if (count + indx > ncircls)
          handles(count + indx) = line('XData', real(pos), 'YData', imag(pos), 'Parent', hgroup, ...
                            'Color', curr_color, 'Marker', 'none');

        % Otherwise, modify the required data, and store the previous handler
        else
          set(hcircls(count + indx), 'XData', real(pos), 'YData', imag(pos), 'Color', curr_color, 'Marker', 'none');
          handles(indx) = hcircls(count + indx);
        end

        % If we ran out of existing circles to modify, creat a new one
        if (count + indx + 1 > ncircls)
          handles(count + indx + 1) = line('XData', curr_spots(s,1), 'YData', curr_spots(s,2), 'Parent', hgroup, ...
                            'Color', curr_color, 'Marker', 'd');

        % Otherwise, modify the required data, and store the previous handler
        else
          set(hcircls(count + indx + 1), 'XData', curr_spots(s,1), 'YData', curr_spots(s,2), 'Color', curr_color, 'Marker', 'd');
          handles(indx + 1) = hcircls(count + indx + 1);
        end
      else
        % If we ran out of existing circles to modify, creat a new one
        if (count+s > ncircls)
          handles(s) = line('XData', real(pos), 'YData', imag(pos), 'Parent', hgroup, ...
                            'Color', curr_color, 'Marker', 'none');

        % Otherwise, modify the required data, and store the previous handler
        else
          set(hcircls(count+s), 'XData', real(pos), 'YData', imag(pos), 'Color', curr_color, 'Marker', 'none');
          handles(s) = hcircls(count+s);
        end
      end
    end

    % Update the total number of drawn circles
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

  % Delete additional previous circles
  delete(hcircls(count+1:ncircls))

  % Prevent the output if not needed
  if (nargout == 0)
    clearvars
  end

  return;
end
